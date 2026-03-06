# Deploy Sydney Trains enrichment components to Fabric workspace
# Creates: Stream_Train_Updates Eventstream + 2 Notebooks (reference data loader + trip update ingestion)
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
# Deploy Train Enrichment Components
# ============================

Write-Host "`n=== Step 1: Create Trip Updates Eventstream ===" -ForegroundColor Cyan
New-FabricItem -Name "Stream_Train_Updates" -Type "Eventstream" -Description "Real-time train trip update data (arrival/departure predictions per stop)"

Write-Host "`n=== Step 2: Create Reference Data Notebook ===" -ForegroundColor Cyan
$repoRoot = $PSScriptRoot
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$refNotebookPath = Join-Path $repoRoot "assets/trains/load_reference_data.ipynb"
New-FabricNotebook -Name "Load Train Reference Data" -NotebookPath $refNotebookPath -Description "Download GTFS static timetable bundle and load stops, routes, stop_times reference tables into TrainAnalysis KQL database"

Write-Host "`n=== Step 3: Create Trip Updates Notebook ===" -ForegroundColor Cyan
$tuNotebookPath = Join-Path $repoRoot "assets/trains/ingest_trip_updates.ipynb"
New-FabricNotebook -Name "Call Train Updates API" -NotebookPath $tuNotebookPath -Description "Retrieve real-time trip updates (arrival/departure predictions) from Transport NSW Sydney Trains v2 API"

# Summary
Write-Host "`n=== Train Enrichment Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Workspace: RTI-Transport ($WorkspaceId)"
Write-Host ""
Write-Host "Created:" -ForegroundColor Green
Write-Host "  Eventstream:  Stream_Train_Updates"
Write-Host "  Notebook:     Load Train Reference Data"
Write-Host "  Notebook:     Call Train Updates API"
Write-Host ""
Write-Host "=== MANUAL STEPS REQUIRED ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "Step 1: Load Reference Data (one-time)" -ForegroundColor Yellow
Write-Host "  a. Open 'Load Train Reference Data' notebook in Fabric portal"
Write-Host "  b. Set myapikey = your Transport NSW API key"
Write-Host "  c. Set kusto_uri = Query URI from TrainAnalysis Eventhouse overview page"
Write-Host "  d. Run all cells - creates StopsReference, RoutesReference, StopTimesReference tables"
Write-Host ""
Write-Host "Step 2: Configure Trip Updates Pipeline" -ForegroundColor Yellow
Write-Host "  a. Open Stream_Train_Updates Eventstream -> Edit -> Add Custom Endpoint source"
Write-Host "  b. Copy the Event Hub connection string"
Write-Host "  c. Open 'Call Train Updates API' notebook"
Write-Host "  d. Set myapikey and myconnectionstring"
Write-Host ""
Write-Host "Step 3: Add Eventhouse Destination" -ForegroundColor Yellow
Write-Host "  a. Open Stream_Train_Updates Eventstream -> Edit -> Add Eventhouse destination"
Write-Host "  b. Select TrainAnalysis Eventhouse -> TrainAnalysis database"
Write-Host "  c. Table name: TripUpdates"
Write-Host "  d. Publish the Eventstream"
Write-Host ""
Write-Host "Step 4: Start Ingestion" -ForegroundColor Yellow
Write-Host "  a. Run 'Call Train Updates API' notebook (continuous polling)"
Write-Host "  b. Verify: TripUpdates | where timestamp > ago(1m) | count"
Write-Host ""
Write-Host "Step 5: Update Dashboard" -ForegroundColor Yellow
Write-Host "  Add enriched KQL queries to your RTI Dashboard - see sample queries below"
Write-Host ""
Write-Host "=== SAMPLE KQL QUERIES ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "-- Train positions with station names --" -ForegroundColor DarkCyan
Write-Host 'SydneyTrains | where timestamp > ago(2m) | summarize arg_max(timestamp, *) by train_id | join kind=leftouter StopsReference on stop_id | project timestamp, train_label, route_id, stop_name, current_status, train_lat, train_long'
Write-Host ""
Write-Host "-- All trains with route name + next stop + ETA --" -ForegroundColor DarkCyan
Write-Host 'let positions = SydneyTrains | where timestamp > ago(2m) | summarize arg_max(timestamp, *) by train_id;'
Write-Host 'let next_stops = TripUpdates | where timestamp > ago(30s) | summarize arg_min(stop_sequence, stop_id, arrival_time, arrival_delay) by trip_id;'
Write-Host 'positions | join kind=leftouter next_stops on trip_id | join kind=leftouter StopsReference on stop_id | join kind=leftouter RoutesReference on route_id | project timestamp, train_label, route_short_name, stop_name, arrival_time, arrival_delay, current_status, train_lat, train_long'
