# Deploy Sydney Trains RTI components to Fabric workspace
param(
    [string]$WorkspaceId = "48b5c12d-84e6-456c-8eb2-5103fd1786ca"
)

$ErrorActionPreference = "Continue"

Write-Host "Getting Fabric API token..." -ForegroundColor Cyan
$token = az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
if (-not $token) { Write-Error "Failed to get token. Run 'az login' first."; exit 1 }
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

# Get existing items
Write-Host "Checking existing workspace items..." -ForegroundColor Cyan
$existingItems = @()
try {
    $existingResp = Invoke-RestMethod -Uri "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/items" -Headers $headers -Method Get
    $existingItems = $existingResp.value
    Write-Host "  Found $($existingItems.Count) existing items" -ForegroundColor Gray
} catch {}

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
                if ($op.status -eq "Failed") { Write-Host "  Failed: $($op | ConvertTo-Json -Compress)" -ForegroundColor Red; return $null }
            }
        } catch { }
        Write-Host "  Waiting... ($elapsed`s)" -ForegroundColor DarkYellow
    }
    return $null
}

function New-FabricItem {
    param([string]$Name, [string]$Type, [string]$Description)
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
            if ($opUrl) { Wait-FabricOperation -OperationUrl $opUrl }
            Start-Sleep -Seconds 5
            Write-Host "  Async creation submitted" -ForegroundColor Yellow
            return $null
        }
    } catch {
        $errorBody = ""
        try { $stream = $_.Exception.Response.GetResponseStream(); $reader = [System.IO.StreamReader]::new($stream); $errorBody = $reader.ReadToEnd() } catch {}
        if ($errorBody -match "AlreadyInUse") { Write-Host "  SKIP: Already exists" -ForegroundColor Green; return $null }
        Write-Host "  Failed: $errorBody" -ForegroundColor Red
        return $null
    }
}

function New-FabricNotebook {
    param([string]$Name, [string]$NotebookPath, [string]$Description)
    $existing = $existingItems | Where-Object { $_.displayName -eq $Name -and $_.type -eq "Notebook" }
    if ($existing) {
        Write-Host "  SKIP: Notebook '$Name' already exists (ID: $($existing.id))" -ForegroundColor Green
        return $existing
    }
    Write-Host "Creating Notebook '$Name'..." -ForegroundColor Yellow
    if (-not (Test-Path $NotebookPath)) { Write-Host "  File not found: $NotebookPath" -ForegroundColor Red; return $null }
    $content = Get-Content -Path $NotebookPath -Raw -Encoding UTF8
    $base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    $body = @{
        displayName = $Name; type = "Notebook"; description = $Description
        definition = @{ format = "ipynb"; parts = @(@{ path = "notebook-content.ipynb"; payload = $base64; payloadType = "InlineBase64" }) }
    } | ConvertTo-Json -Depth 5
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
            if ($opUrl) { Wait-FabricOperation -OperationUrl $opUrl }
            Start-Sleep -Seconds 5
            Write-Host "  Async creation submitted" -ForegroundColor Yellow
            return $null
        }
    } catch {
        $errorBody = ""
        try { $stream = $_.Exception.Response.GetResponseStream(); $reader = [System.IO.StreamReader]::new($stream); $errorBody = $reader.ReadToEnd() } catch {}
        Write-Host "  Failed: $errorBody" -ForegroundColor Red
        return $null
    }
}

# ============================
# Deploy Sydney Trains Components
# ============================

Write-Host "`n=== Step 1: Create Trains Eventhouse ===" -ForegroundColor Cyan
New-FabricItem -Name "TrainAnalysis" -Type "Eventhouse" -Description "Real-time train position tracking for Sydney Trains network"

Write-Host "`n=== Step 2: Create Trains Eventstream ===" -ForegroundColor Cyan
New-FabricItem -Name "Stream_Train_Loc" -Type "Eventstream" -Description "Real-time train position data processing"

Write-Host "`n=== Step 3: Create Trains Notebook ===" -ForegroundColor Cyan
$repoRoot = $PSScriptRoot
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$trainNotebookPath = Join-Path $repoRoot "assets\trains\ingest_trains.ipynb"
New-FabricNotebook -Name "Call Trains API" -NotebookPath $trainNotebookPath -Description "Retrieve real-time train positions from Transport NSW Sydney Trains v2 API"

# Summary
Write-Host "`n=== Trains Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Workspace: RTI-Transport ($WorkspaceId)"
Write-Host "Eventhouse: TrainAnalysis (separate from TransportAnalysis and FerryAnalysis)"
Write-Host "Eventstream: Stream_Train_Loc"
Write-Host "Notebook: Call Trains API (uses v2 API)"
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Open Stream_Train_Loc -> Add Custom Endpoint source"
Write-Host "2. Copy the Event Hub connection string"
Write-Host "3. Open 'Call Trains API' notebook, set myapikey and myconnectionstring"
Write-Host "4. Add Eventhouse destination -> TrainAnalysis -> table 'SydneyTrains'"
Write-Host "5. Run the notebook to start train data ingestion"
Write-Host "6. Create RTI Dashboard with train KQL queries"
