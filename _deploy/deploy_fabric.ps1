# Deploy Fabric RTI Transport Analysis resources
param(
    [string]$WorkspaceId = "48b5c12d-84e6-456c-8eb2-5103fd1786ca"
)

$ErrorActionPreference = "Continue"

# Get token
Write-Host "Getting Fabric API token..." -ForegroundColor Cyan
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
if (-not $token) { Write-Error "Failed to get token. Run 'az login' first."; exit 1 }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# Get existing items to avoid duplicates
Write-Host "Checking existing workspace items..." -ForegroundColor Cyan
$existingItems = @()
try {
    $existingResp = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Headers $headers -Method Get
    $existingItems = $existingResp.value
    if ($existingItems.Count -gt 0) {
        Write-Host "  Found $($existingItems.Count) existing items:" -ForegroundColor Yellow
        $existingItems | ForEach-Object { Write-Host "    - $($_.displayName) ($($_.type))" -ForegroundColor Gray }
    }
} catch { Write-Host "  Could not list items, will attempt creation." -ForegroundColor Yellow }

function Wait-FabricOperation {
    param([string]$OperationUrl, [int]$MaxWaitSeconds = 120)
    $elapsed = 0
    while ($elapsed -lt $MaxWaitSeconds) {
        Start-Sleep -Seconds 3
        $elapsed += 3
        try {
            $opResp = Invoke-WebRequest -Uri $OperationUrl -Headers $headers -Method Get -UseBasicParsing
            if ($opResp.StatusCode -eq 200) {
                $op = $opResp.Content | ConvertFrom-Json
                if ($op.status -eq "Succeeded") { return $op }
                if ($op.status -eq "Failed") { Write-Host "  Operation failed: $($op | ConvertTo-Json -Compress)" -ForegroundColor Red; return $null }
            }
        } catch { }
        Write-Host "  Waiting... ($elapsed`s)" -ForegroundColor DarkYellow
    }
    Write-Host "  Timed out after $MaxWaitSeconds`s" -ForegroundColor Red
    return $null
}

function New-FabricItem {
    param([string]$Name, [string]$Type, [string]$Description)
    
    # Check if already exists
    $existing = $existingItems | Where-Object { $_.displayName -eq $Name -and $_.type -eq $Type }
    if ($existing) {
        Write-Host "  SKIP: $Type '$Name' already exists (ID: $($existing.id))" -ForegroundColor Green
        return $existing
    }
    
    Write-Host "Creating $Type '$Name'..." -ForegroundColor Yellow
    $body = @{ displayName = $Name; type = $Type; description = $Description } | ConvertTo-Json
    try {
        $response = Invoke-WebRequest -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Headers $headers -Method Post -Body $body -UseBasicParsing
        if ($response.StatusCode -eq 201 -or $response.StatusCode -eq 200) {
            $item = $response.Content | ConvertFrom-Json
            Write-Host "  Created: $($item.displayName) (ID: $($item.id))" -ForegroundColor Green
            return $item
        } elseif ($response.StatusCode -eq 202) {
            Write-Host "  Provisioning (async)..." -ForegroundColor Yellow
            $opUrl = $null
            if ($response.Headers["Location"]) { $opUrl = $response.Headers["Location"] }
            elseif ($response.Headers.ContainsKey("x-ms-operation-id")) {
                $opId = $response.Headers["x-ms-operation-id"]
                $opUrl = "https://api.fabric.microsoft.com/v1/operations/$opId"
            }
            if ($opUrl) {
                $result = Wait-FabricOperation -OperationUrl $opUrl
                if ($result) { return $result }
            }
            # Even if we can't poll, the item may have been created
            Start-Sleep -Seconds 5
            Write-Host "  Async creation submitted" -ForegroundColor Yellow
            return $null
        }
    } catch {
        $statusCode = 0
        $errorBody = ""
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $errorBody = $reader.ReadToEnd()
        } catch {}
        if ($errorBody -match "AlreadyInUse|already exists") {
            Write-Host "  SKIP: $Type '$Name' already exists" -ForegroundColor Green
            return $null
        }
        Write-Host "  Failed ($statusCode): $errorBody" -ForegroundColor Red
        return $null
    }
}

# 1. Create Eventhouse
Write-Host "`n=== Step 1: Create Eventhouse ===" -ForegroundColor Cyan
$eventhouse = New-FabricItem -Name "TransportAnalysis" -Type "Eventhouse" -Description "Central data repository for transport RTI analysis"

# 2. Create Eventstreams
Write-Host "`n=== Step 2: Create Eventstreams ===" -ForegroundColor Cyan
$esBus = New-FabricItem -Name "Stream_Bus_Loc" -Type "Eventstream" -Description "Real-time bus position data processing"
$esHazard = New-FabricItem -Name "Stream_Live_Info" -Type "Eventstream" -Description "Real-time hazard and incident data processing"

# 3. Create Notebooks - need to upload the .ipynb content as base64
Write-Host "`n=== Step 3: Create Notebooks ===" -ForegroundColor Cyan

$repoRoot = $PSScriptRoot
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$busNotebookPath = Join-Path $repoRoot "assets\buses\ingest.ipynb"
$hazardNotebookPath = Join-Path $repoRoot "assets\hazards\ingesthz.ipynb"

# For notebooks, Fabric API requires a specific payload with definition
function New-FabricNotebook {
    param([string]$Name, [string]$NotebookPath, [string]$Description)
    
    # Check if already exists
    $existing = $existingItems | Where-Object { $_.displayName -eq $Name -and $_.type -eq "Notebook" }
    if ($existing) {
        Write-Host "  SKIP: Notebook '$Name' already exists (ID: $($existing.id))" -ForegroundColor Green
        return $existing
    }
    
    Write-Host "Creating Notebook '$Name' from $NotebookPath..." -ForegroundColor Yellow
    
    if (-not (Test-Path $NotebookPath)) {
        Write-Host "  File not found: $NotebookPath" -ForegroundColor Red
        return $null
    }
    
    $notebookContent = Get-Content -Path $NotebookPath -Raw -Encoding UTF8
    $base64Content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($notebookContent))
    
    $body = @{
        displayName = $Name
        type = "Notebook"
        description = $Description
        definition = @{
            format = "ipynb"
            parts = @(
                @{
                    path = "notebook-content.ipynb"
                    payload = $base64Content
                    payloadType = "InlineBase64"
                }
            )
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        $response = Invoke-WebRequest -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Headers $headers -Method Post -Body $body -UseBasicParsing
        if ($response.StatusCode -eq 201 -or $response.StatusCode -eq 200) {
            $item = $response.Content | ConvertFrom-Json
            Write-Host "  Created: $($item.displayName) (ID: $($item.id))" -ForegroundColor Green
            return $item
        } elseif ($response.StatusCode -eq 202) {
            Write-Host "  Provisioning notebook (async)..." -ForegroundColor Yellow
            $opUrl = $null
            if ($response.Headers["Location"]) { $opUrl = $response.Headers["Location"] }
            elseif ($response.Headers.ContainsKey("x-ms-operation-id")) {
                $opId = $response.Headers["x-ms-operation-id"]
                $opUrl = "https://api.fabric.microsoft.com/v1/operations/$opId"
            }
            if ($opUrl) {
                $result = Wait-FabricOperation -OperationUrl $opUrl
                if ($result) { return $result }
            }
            Start-Sleep -Seconds 5
            Write-Host "  Async creation submitted" -ForegroundColor Yellow
            return $null
        }
    } catch {
        $statusCode = 0
        $errorBody = ""
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($stream)
            $errorBody = $reader.ReadToEnd()
        } catch {}
        if ($errorBody -match "AlreadyInUse|already exists") {
            Write-Host "  SKIP: Notebook '$Name' already exists" -ForegroundColor Green
            return $null
        }
        Write-Host "  Failed ($statusCode): $errorBody" -ForegroundColor Red
        return $null
    }
}

$nbBus = New-FabricNotebook -Name "Call Buses API" -NotebookPath $busNotebookPath -Description "Retrieve real-time vehicle position data from Transport NSW APIs"
$nbHazard = New-FabricNotebook -Name "Call Hazards API" -NotebookPath $hazardNotebookPath -Description "Fetch live hazard and incident data from traffic management systems"

# Summary
Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Workspace: RTI-Transport ($WorkspaceId)"
Write-Host "Eventhouse: TransportAnalysis"
Write-Host "Eventstreams: Stream_Bus_Loc, Stream_Live_Info"
Write-Host "Notebooks: Call Buses API, Call Hazards API"
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Open Fabric portal and configure custom endpoints on Eventstreams"
Write-Host "2. Get Event Hub connection strings from each Eventstream"
Write-Host "3. Register at opendata.transport.nsw.gov.au for API key"
Write-Host "4. Update myapikey and myconnectionstring in both notebooks"
Write-Host "5. Add Eventhouse destinations to each Eventstream"
Write-Host "6. Run notebooks to start data ingestion"
