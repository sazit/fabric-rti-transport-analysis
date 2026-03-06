#!/usr/bin/env python3
"""
Test all dashboard KQL queries against the TrainAnalysis Eventhouse.

Usage:
    python test_dashboard_queries.py --kusto-uri https://<guid>.<region>.kusto.fabric.microsoft.com

Requires: Azure CLI logged in (az login)
"""

import argparse
import json
import subprocess
import sys
import requests


def get_kusto_token():
    """Get an access token for Kusto/Eventhouse via Azure CLI."""
    result = subprocess.run(
        ["az", "account", "get-access-token", "--resource", "https://kusto.kusto.windows.net", "--query", "accessToken", "-o", "tsv"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: az CLI auth failed: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()


def run_query(kusto_uri, token, database, query, name):
    """Execute a KQL query and print result summary."""
    url = f"{kusto_uri}/v2/rest/query"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    body = {
        "db": database,
        "csl": query,
        "properties": json.dumps({
            "Options": {"query_language": "kql", "servertimeout": "00:01:00"}
        }),
    }

    resp = requests.post(url, headers=headers, json=body, timeout=120)

    if resp.status_code != 200:
        print(f"  ❌ {name}: HTTP {resp.status_code} — {resp.text[:200]}")
        return False

    frames = resp.json()
    # Find the primary result table
    for frame in frames:
        if frame.get("FrameType") == "DataTable" and frame.get("TableKind") == "PrimaryResult":
            rows = frame.get("Rows", [])
            cols = [c["ColumnName"] for c in frame.get("Columns", [])]
            print(f"  ✅ {name}: {len(rows)} rows, columns: {cols}")
            if rows:
                print(f"     Sample: {rows[0]}")
            return True

    print(f"  ⚠️  {name}: No primary result table found")
    return False


# --- Dashboard queries (parameters replaced with test defaults) ---

QUERIES = {
    "Tile 1 — Data Freshness": """
Trains
| summarize LatestData = max(todatetime(timestamp))
| project
    DataAsOf = format_datetime(LatestData, 'dd MMM yyyy HH:mm:ss'),
    AgeSeconds = datetime_diff('second', now(), LatestData)
""",

    "Tile 2 — Live Train Map (trains only)": """
Trains
| where todatetime(timestamp) > ago(5m)
| summarize arg_max(todatetime(timestamp), *) by train_id
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
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
| extend speed_kmh = round(toreal(train_speed) * 3.6, 1)
| project train_id, train_label, train_lat, train_long, line_name, speed_kmh, stop_id, current_status
| take 10
""",

    "Tile 2 — Station Markers": """
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
| project stop_name, stop_lat, stop_lon
""",

    "Tile 2 — TripUpdates Join": """
TripUpdates
| where todatetime(timestamp) > ago(5m)
| summarize arg_min(toint(stop_sequence), *) by trip_id
| project trip_id, stop_id, arrival_delay, departure_delay
| take 10
""",

    "Tile 3 — Active Trains by Line": """
Trains
| where todatetime(timestamp) > ago(5m)
| summarize arg_max(todatetime(timestamp), *) by train_id
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
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
""",

    "Tile 4 — Delayed Trains": """
TripUpdates
| where todatetime(timestamp) > ago(5m)
| where toint(arrival_delay) > 60
| summarize arg_max(todatetime(timestamp), *) by trip_id, stop_id
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
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
| project Line = line_name, Trip = trip_id, Stop = coalesce(stop_name, stop_id), DelayMins = delay_mins
| order by DelayMins desc
| take 10
""",

    "Tile 5 — Departure Board (Central)": """
let station_stops = StopsReference
| where stop_name has "Central"
| project stop_id;
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
| project Line = line_name, Trip = trip_id, Due = arrival_time, DelayMins = delay_mins
| order by Due asc
| take 15
""",

    "Tile 6 — Avg Delay by Line": """
TripUpdates
| where todatetime(timestamp) > ago(30m)
| where toint(arrival_delay) > 0
| extend line_name = case(
    route_id startswith "NSN", "T1 North Shore",
    route_id startswith "WST", "T1 Western",
    route_id startswith "IWL", "T2 Inner West",
    route_id startswith "CMB" or route_id startswith "T3", "T3 Bankstown",
    route_id startswith "ESI", "T4 Eastern Suburbs",
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
| summarize AvgDelay = round(avg(delay_mins), 1), MaxDelay = round(max(delay_mins), 1), DelayedTrips = dcount(trip_id) by line_name
| order by AvgDelay desc
""",

    "Tile 7 — Train Count Over Time": """
Trains
| where todatetime(timestamp) > ago(1h)
| extend ts = bin(todatetime(timestamp), 1m)
| summarize ActiveTrains = dcount(train_id) by ts
| order by ts asc
""",

    "Tile 8 — Network Health": """
let total = Trains
| where todatetime(timestamp) > ago(5m)
| summarize arg_max(todatetime(timestamp), *) by train_id
| count
| project Metric = "Active Trains", Value = tolong(Count);
let delayed = TripUpdates
| where todatetime(timestamp) > ago(5m)
| where toint(arrival_delay) > 120
| summarize dcount(trip_id)
| project Metric = "Delayed >2min", Value = tolong(dcount_trip_id);
let on_time_pct = TripUpdates
| where todatetime(timestamp) > ago(5m)
| summarize total_updates = count(), on_time = countif(toint(arrival_delay) <= 60)
| project Metric = "On-Time Pct", Value = tolong(round(toreal(on_time) / toreal(total_updates) * 100, 0));
union total, delayed, on_time_pct
""",

    "Reference — StopsReference Count": "StopsReference | count",
    "Reference — RoutesReference Count": "RoutesReference | count",
    "Reference — StopTimesReference Count": "StopTimesReference | count",
}


def main():
    parser = argparse.ArgumentParser(description="Test dashboard KQL queries against TrainAnalysis Eventhouse")
    parser.add_argument("--kusto-uri", required=True, help="Eventhouse Query URI (https://<guid>.<region>.kusto.fabric.microsoft.com)")
    parser.add_argument("--database", default="TrainAnalysis", help="KQL database name (default: TrainAnalysis)")
    args = parser.parse_args()

    print("Authenticating via Azure CLI...")
    token = get_kusto_token()
    print(f"Token acquired. Testing {len(QUERIES)} queries against {args.database}...\n")

    passed = 0
    failed = 0
    for name, query in QUERIES.items():
        ok = run_query(args.kusto_uri, token, args.database, query.strip(), name)
        if ok:
            passed += 1
        else:
            failed += 1

    print(f"\n{'='*50}")
    print(f"Results: {passed} passed, {failed} failed out of {len(QUERIES)}")
    if failed == 0:
        print("All queries OK — ready to build the dashboard!")
    else:
        print("Some queries failed. Check Eventhouse connectivity and table data.")


if __name__ == "__main__":
    main()
