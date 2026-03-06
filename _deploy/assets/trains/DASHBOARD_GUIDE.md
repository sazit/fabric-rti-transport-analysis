# Sydney Trains Enriched — KQL Dashboard Build Guide

Build a comprehensive real-time intelligence dashboard for Sydney Trains in Microsoft Fabric. This guide provides every KQL query, parameter definition, tile configuration, and layout instruction needed to create the dashboard in the Fabric portal.

## Prerequisites

| Item | Status |
|------|--------|
| TrainAnalysis Eventhouse running | ✅ |
| `Trains` table receiving vehicle positions | ✅ |
| `TripUpdates` table receiving trip updates | ✅ |
| `StopsReference` table populated (~35K rows) | ✅ |
| `RoutesReference` table populated (~50 rows) | ✅ |
| `StopTimesReference` table populated (~2M rows) | ✅ |

> **Important:** The vehicle position table is named `Trains` in the Eventhouse (not `SydneyTrains`). All queries below use `Trains`.

---

## Step 1: Create the Dashboard

1. Open the **RTI-Transport** workspace in Fabric
2. Click **+ New** → **Real-Time Intelligence** → **Real-Time Dashboard**
3. Name it **Sydney Trains Enriched**
4. When prompted, add a data source:
   - **Name:** `TrainAnalysis`
   - **Database:** Select **TrainAnalysis** from the Eventhouse
5. Click **Create**

---

## Step 2: Add Parameters

Add these 3 parameters via **Parameters** (top-right of the dashboard editor).

### Parameter 1: ShowReplacement

| Setting | Value |
|---------|-------|
| Label | Show Replacement Services |
| Variable name | `ShowReplacement` |
| Type | Single selection |
| Data type | string |
| Values | Fixed values: `Yes`, `No` |
| Default | `No` |

### Parameter 2: ShowStations

| Setting | Value |
|---------|-------|
| Label | Show Station Markers |
| Variable name | `ShowStations` |
| Type | Single selection |
| Data type | string |
| Values | Fixed values: `Yes`, `No` |
| Default | `Yes` |

### Parameter 3: SelectedStation

| Setting | Value |
|---------|-------|
| Label | Station |
| Variable name | `SelectedStation` |
| Type | Single selection |
| Data type | string |
| Source | Query |

**Parameter query:**
```kql
StopsReference
| where location_type == "1"
| where stop_name has_any (
    "Central", "Town Hall", "Wynyard", "Circular Quay", "Martin Place",
    "Kings Cross", "Redfern", "Strathfield", "Parramatta", "Blacktown",
    "Penrith", "Hornsby", "Chatswood", "North Sydney", "Epping",
    "Lidcombe", "Olympic Park", "Bankstown", "Hurstville", "Sutherland",
    "Cronulla", "Bondi Junction", "Sydenham", "Domestic Airport",
    "International Airport", "Richmond", "Campbelltown", "Liverpool",
    "Gosford", "Newcastle Interchange"
)
| project stop_name
| order by stop_name asc
```

**Default:** `Central`

---

## Step 3: Add Tiles

### Color Reference

All queries below use this `case()` mapping for line name and color:

```
line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
```

> **Note:** Trains with an empty `route_id` are non-revenue/maintenance movements and are filtered out of all dashboard queries with `| where isnotempty(route_id)`.

When configuring map or chart colors in the visual, set category colors to:

| Line | Hex Color |
|------|-----------|
| T1 North Shore | `#F99D1C` |
| T1 Western | `#F99D1C` |
| T2 Inner West | `#0098CD` |
| T3 Bankstown | `#F37021` |
| T4 Eastern Suburbs | `#005AA3` |
| T7 Olympic Park | `#00954C` |
| T8 Airport | `#6F818E` |
| T9 Northern | `#D11F2F` |
| Blue Mountains | `#00B5EF` |
| Central Coast | `#78BE20` |
| Hunter | `#833134` |
| South Coast | `#005AA3` |
| Sthn Highlands | `#005AA3` |
| Intercity | `#6F818E` |
| T6 Carlingford | `#8D5B2D` |
| Replacement Svc | `#999999` |
| Station | `#333333` |

---

### Tile 1: Data Freshness

**Visual type:** Stat

**Query:**
```kql
Trains
| summarize LatestData = max(todatetime(timestamp))
| project
    DataAsOf = format_datetime(LatestData, 'dd MMM yyyy HH:mm:ss'),
    AgeSeconds = datetime_diff('second', now(), LatestData)
```

**Configuration:**
- Value column: `DataAsOf`
- Title: **Data as at**
- Size: Small tile (1×1), place in top-right corner

---

### Tile 2: Live Train Map

This is the main tile. It shows coloured train dots and dark station markers on a single map.

**Visual type:** Map

**Query:**
```kql
// --- Train positions enriched with stop name, line, speed, delay ---
let train_data = Trains
| where todatetime(timestamp) > ago(2m)
| where isnotempty(route_id)
| summarize arg_max(todatetime(timestamp), *) by train_id
| extend is_replacement = route_id startswith "RTTA"
| where ('ShowReplacement' == "Yes" or is_replacement == false)
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
| extend speed_kmh = round(toreal(train_speed) * 3.6, 1);
// --- Join next-stop info from TripUpdates ---
let trip_delays = TripUpdates
| where todatetime(timestamp) > ago(2m)
| summarize arg_min(toint(stop_sequence), *) by trip_id
| project trip_id,
    next_stop_id = stop_id,
    arrival_delay_sec = toint(arrival_delay),
    departure_delay_sec = toint(departure_delay);
// --- Join reference tables ---
let enriched = train_data
| join kind=leftouter trip_delays on trip_id
| join kind=leftouter (StopsReference | project stop_id, next_stop_name = stop_name) on $left.next_stop_id == $right.stop_id
| join kind=leftouter (
    StopsReference
    | project stop_id, current_stop_name = stop_name
) on $left.stop_id == $right.stop_id
| extend
    display_stop = coalesce(next_stop_name, current_stop_name, stop_id),
    delay_mins = iff(isnotnull(arrival_delay_sec), round(toreal(arrival_delay_sec) / 60.0, 1), real(null)),
    delay_label = case(
        isnotnull(arrival_delay_sec) and arrival_delay_sec > 300, strcat("+", tostring(round(toreal(arrival_delay_sec)/60.0, 0)), "m late"),
        isnotnull(arrival_delay_sec) and arrival_delay_sec > 60, strcat("+", tostring(round(toreal(arrival_delay_sec)/60.0, 0)), "m"),
        isnotnull(arrival_delay_sec) and arrival_delay_sec >= -30, "On time",
        isnotnull(arrival_delay_sec), strcat(tostring(round(toreal(arrival_delay_sec)/60.0, 0)), "m early"),
        ""
    ),
    point_type = "Train",
    marker_size = 6
| project
    point_type, marker_size,
    Latitude = train_lat, Longitude = train_long,
    Label = coalesce(train_label, train_id),
    line_name, speed_kmh,
    NextStop = display_stop,
    delay_mins, delay_label,
    Status = current_status,
    timestamp;
// --- Station markers (major interchanges) ---
let stations = StopsReference
| where location_type == "1"
| where stop_name has_any (
    "Central", "Town Hall", "Wynyard", "Circular Quay", "Martin Place",
    "Kings Cross", "Redfern", "Strathfield", "Parramatta", "Blacktown",
    "Penrith", "Hornsby", "Chatswood", "North Sydney", "Epping",
    "Lidcombe", "Olympic Park", "Bankstown", "Hurstville", "Sutherland",
    "Cronulla", "Bondi Junction", "Sydenham", "Domestic Airport",
    "International Airport", "Richmond", "Campbelltown", "Liverpool",
    "Gosford", "Newcastle Interchange"
)
| where 'ShowStations' == "Yes"
| project
    point_type = "Station",
    marker_size = 10,
    Latitude = stop_lat, Longitude = stop_lon,
    Label = stop_name,
    line_name = "Station",
    speed_kmh = real(null),
    NextStop = "",
    delay_mins = real(null),
    delay_label = "",
    Status = "",
    timestamp = datetime(null);
// --- Combine ---
union enriched, stations
| where Latitude between (-35.5 .. -32.5) and Longitude between (149.5 .. 152.5)
```

**Configuration:**
- **Latitude column:** `Latitude`
- **Longitude column:** `Longitude`
- **Label column / Tooltip:** `Label`
- **Color by:** `line_name` (then set each category's color per the table above)
- **Size by:** `marker_size` (if supported — otherwise use fixed size)
- **Tooltip columns:** `Label`, `line_name`, `speed_kmh`, `NextStop`, `delay_label`, `Status`
- **Title:** Live Train Map
- **Size:** Large tile (takes up ~60% of dashboard width)

---

### Tile 3: Active Trains by Line

**Visual type:** Bar chart (horizontal)

**Query:**
```kql
Trains
| where todatetime(timestamp) > ago(2m)
| where isnotempty(route_id)
| summarize arg_max(todatetime(timestamp), *) by train_id
| extend is_replacement = route_id startswith "RTTA"
| where ('ShowReplacement' == "Yes" or is_replacement == false)
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
| summarize TrainCount = dcount(train_id) by line_name
| order by TrainCount desc
```

**Configuration:**
- **Y axis:** `line_name`
- **X axis:** `TrainCount`
- **Color by:** `line_name` (set colors per the table above)
- **Title:** Active Trains by Line
- **Size:** Medium tile (right side, 2×1)

---

### Tile 4: Delayed Trains

**Visual type:** Table

**Query:**
```kql
TripUpdates
| where todatetime(timestamp) > ago(2m)
| where toint(arrival_delay) > 60
| summarize arg_max(todatetime(timestamp), *) by trip_id, stop_id
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
| extend delay_mins = round(toreal(arrival_delay) / 60.0, 1)
| join kind=leftouter (StopsReference | project stop_id, stop_name) on stop_id
| project
    Line = line_name,
    Trip = trip_id,
    Stop = coalesce(stop_name, stop_id),
    DelayMins = delay_mins,
    Status = schedule_relationship
| order by DelayMins desc
| take 20
```

**Configuration:**
- **Columns:** Line, Trip, Stop, DelayMins, Status
- **Conditional formatting on DelayMins:**
  - Green: 1–3 min
  - Amber: 3–5 min
  - Red: >5 min
- **Title:** Delayed Trains
- **Size:** Medium tile (2×1), below Active Trains

---

### Tile 5: Departure Board

Shows next departures from the selected station. This is the most complex query — it resolves the destination (terminal station) for each trip.

**Visual type:** Table

**Query:**
```kql
// Find child stop_ids for the selected station
let station_stops = StopsReference
| where stop_name has 'SelectedStation'
| project stop_id;
// Find trip destinations (last stop in each trip)
let trip_destinations = StopTimesReference
| summarize max_seq = max(toint(stop_sequence)) by trip_id
| join kind=inner (
    StopTimesReference | project trip_id, stop_sequence, dest_stop_id = stop_id
) on trip_id
| where toint(stop_sequence) == max_seq
| join kind=leftouter (StopsReference | project stop_id, destination = stop_name) on $left.dest_stop_id == $right.stop_id
| project trip_id, destination;
// Get upcoming arrivals at the selected station from TripUpdates
TripUpdates
| where todatetime(timestamp) > ago(5m)
| where stop_id in (station_stops)
| summarize arg_max(todatetime(timestamp), *) by trip_id, stop_id
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
| extend delay_mins = round(toreal(arrival_delay) / 60.0, 1)
| extend status_label = case(
    toint(arrival_delay) <= 60, "On time",
    toint(arrival_delay) <= 300, strcat("+", tostring(round(toreal(arrival_delay)/60.0, 0)), " min"),
    strcat("+", tostring(round(toreal(arrival_delay)/60.0, 0)), " min LATE")
)
| join kind=leftouter (StopsReference | project stop_id, platform = stop_name) on stop_id
| join kind=leftouter trip_destinations on trip_id
| project
    Line = line_name,
    Destination = coalesce(destination, ""),
    Due = arrival_time,
    Delay = delay_mins,
    Status = status_label,
    schedule_relationship
| where schedule_relationship != "SKIPPED"
| project-away schedule_relationship
| order by Due asc
| take 15
```

**Configuration:**
- **Columns:** Line, Destination, Due, Delay, Status
- **Conditional formatting on Status:**
  - Green background: "On time"
  - Amber background: contains "+X min" (≤5)
  - Red background: contains "LATE"
- **Title:** Departures from {SelectedStation}
- **Size:** Medium tile (2×2), bottom-left area

---

### Tile 6: Average Delay by Line

**Visual type:** Bar chart (horizontal)

**Query:**
```kql
TripUpdates
| where todatetime(timestamp) > ago(30m)
| where toint(arrival_delay) > 0
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
    route_id startswith "T6", "T6 Carlingford",
    route_id startswith "OLY", "T7 Olympic Park",
    route_id startswith "APS", "T8 Airport",
    route_id startswith "NTH", "T9 Northern",
    route_id startswith "BMT", "Blue Mountains",
    route_id startswith "CCN", "Central Coast",
    route_id startswith "HUN", "Hunter",
    route_id startswith "SCO", "South Coast",
    route_id startswith "SHL", "Sthn Highlands",
    route_id startswith "CTY", "Intercity",
    route_id startswith "RTTA", "Replacement Svc",
    "Other"
)
| extend delay_mins = toreal(arrival_delay) / 60.0
| summarize
    AvgDelay = round(avg(delay_mins), 1),
    MaxDelay = round(max(delay_mins), 1),
    DelayedTrips = dcount(trip_id)
    by line_name
| order by AvgDelay desc
```

**Configuration:**
- **Y axis:** `line_name`
- **X axis:** `AvgDelay`
- **Color by:** `line_name` (set colors per the table above)
- **Tooltip:** `MaxDelay`, `DelayedTrips`
- **Title:** Avg Delay by Line (last 30 min)
- **Size:** Medium tile (2×1)

---

### Tile 7: Train Count Over Time

**Visual type:** Time chart (line)

**Query:**
```kql
Trains
| where todatetime(timestamp) > ago(1h)
| extend ts = bin(todatetime(timestamp), 1m)
| summarize ActiveTrains = dcount(train_id) by ts
| order by ts asc
```

**Configuration:**
- **X axis:** `ts`
- **Y axis:** `ActiveTrains`
- **Title:** Active Trains (last hour)
- **Size:** Medium tile (2×1), bottom of dashboard

---

### Tile 8: Network Health Summary

**Visual type:** Multi stat (or Stat tiles)

**Query:**
```kql
let total = Trains
| where todatetime(timestamp) > ago(2m)
| summarize arg_max(todatetime(timestamp), *) by train_id
| count
| project Metric = "Active Trains", Value = tolong(Count);
let delayed = TripUpdates
| where todatetime(timestamp) > ago(2m)
| where toint(arrival_delay) > 120
| summarize dcount(trip_id)
| project Metric = "Delayed (>2min)", Value = tolong(dcount_trip_id);
let avg_delay = TripUpdates
| where todatetime(timestamp) > ago(5m)
| where toint(arrival_delay) > 0
| summarize avg(toreal(arrival_delay))
| project Metric = "Avg Delay (sec)", Value = tolong(avg_arrival_delay);
let on_time_pct = TripUpdates
| where todatetime(timestamp) > ago(5m)
| summarize
    total_updates = count(),
    on_time = countif(toint(arrival_delay) <= 60)
| project Metric = "On-Time %", Value = tolong(round(toreal(on_time) / toreal(total_updates) * 100, 0));
union total, delayed, avg_delay, on_time_pct
```

**Configuration:**
- Show as 4 separate stat tiles or a single multi-stat tile
- **Title:** Network Health
- **Size:** Row of small tiles (1×1 each) across the top

---

## Step 4: Configure Auto-Refresh

1. Click the **⚙️ Settings** gear icon in the dashboard toolbar
2. Set **Auto refresh** to **30 seconds**
3. Click **Apply**

---

## Step 5: Arrange Layout

Suggested layout (12-column grid):

```
┌─────────────────────────────────────────────────┐
│ Active Trains │ Delayed(>2m) │ Avg Delay │ On-Time%│  Data as at
│    (stat)     │   (stat)     │  (stat)   │ (stat)  │   (stat)
├───────────────────────────────┬──────────────────┤
│                               │ Active Trains    │
│     Live Train Map            │   by Line        │
│       (map - large)           │  (bar chart)     │
│                               ├──────────────────┤
│                               │ Delayed Trains   │
│                               │   (table)        │
├───────────────────────────────┼──────────────────┤
│ Departures from {Station}     │ Avg Delay by Line│
│   (table - departure board)   │  (bar chart)     │
├───────────────────────────────┴──────────────────┤
│           Active Trains (last hour)              │
│              (time chart)                        │
└──────────────────────────────────────────────────┘
```

---

## Tips & Troubleshooting

### Map colors not showing per line?
KQL Dashboard maps color by a **Category** column. Set `line_name` as the **Color by** field, then manually assign each category's color in the visual settings panel. The hex codes are listed in the Color Reference table above.

### Station markers same size as train dots?
If the map visual doesn't support per-row sizing via `marker_size`, you can differentiate stations by:
- Using a different `line_name` value ("Station") which gets its own darker color (`#333333`)
- Or creating a separate map tile just for stations as a reference overlay

### Departure board shows no data?
Check that:
1. `TripUpdates` has recent data: `TripUpdates | where todatetime(timestamp) > ago(2m) | count`
2. The selected station has child stops: `StopsReference | where stop_name has "Central" | project stop_id, stop_name, location_type`
3. There are trip updates for those stops: `TripUpdates | where stop_id in (StopsReference | where stop_name has "Central" | project stop_id) | count`

### Parameter not filtering?
Parameters are referenced in queries using single quotes: `'ShowReplacement'`, `'SelectedStation'`. Make sure the variable name matches exactly (case-sensitive).

### Speed shows 0 for many trains?
`train_speed` from GTFS is often 0 when the train is stationary. This is correct — it only reports non-zero speed when the train is moving. Trains with `current_status == "STOPPED_AT"` will typically show 0 km/h.
