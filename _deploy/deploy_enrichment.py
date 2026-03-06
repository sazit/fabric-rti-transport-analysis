#!/usr/bin/env python3
"""Deploy train enrichment components to Fabric workspace."""
import json
import base64
import subprocess
import urllib.request
import urllib.error
import os

WORKSPACE_ID = "48b5c12d-84e6-456c-8eb2-5103fd1786ca"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def get_token():
    result = subprocess.run(
        ["az", "account", "get-access-token",
         "--resource", "https://api.fabric.microsoft.com",
         "--query", "accessToken", "-o", "tsv"],
        capture_output=True, text=True
    )
    token = result.stdout.strip()
    if not token:
        raise RuntimeError("Failed to get token. Run 'az login' first.")
    return token


def fabric_api(method, path, token, body=None):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{WORKSPACE_ID}/{path}"
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(
        url, data=data,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method=method
    )
    try:
        resp = urllib.request.urlopen(req)
        return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8")


def create_notebook(name, notebook_path, description, token):
    print(f"Creating Notebook '{name}'...")
    with open(notebook_path, "r", encoding="utf-8") as f:
        content = f.read()
    b64 = base64.b64encode(content.encode("utf-8")).decode("ascii")
    body = {
        "displayName": name,
        "type": "Notebook",
        "description": description,
        "definition": {
            "format": "ipynb",
            "parts": [{"path": "notebook-content.ipynb",
                        "payload": b64, "payloadType": "InlineBase64"}]
        }
    }
    status, resp = fabric_api("POST", "items", token, body)
    if status in (200, 201):
        print(f"  CREATED: {resp.get('displayName')} (ID: {resp.get('id')})")
    elif status == 202:
        print(f"  PROVISIONING (async) - check workspace in portal")
    elif "AlreadyInUse" in str(resp):
        print(f"  SKIP: '{name}' already exists")
    else:
        print(f"  ERROR ({status}): {resp}")


def main():
    print("Getting Fabric API token...")
    token = get_token()
    print(f"Token acquired (length: {len(token)})")

    # Check existing items
    status, resp = fabric_api("GET", "items", token)
    existing = [i["displayName"] for i in resp.get("value", [])]
    print(f"Workspace has {len(existing)} items")

    # 1. Eventstream
    if "Stream_Train_Updates" in existing:
        print("\nEventstream 'Stream_Train_Updates' already exists - SKIP")
    else:
        print("\nCreating Eventstream 'Stream_Train_Updates'...")
        body = {"displayName": "Stream_Train_Updates", "type": "Eventstream",
                "description": "Real-time train trip update data"}
        status, resp = fabric_api("POST", "items", token, body)
        print(f"  Result ({status}): {resp}")

    # 2. Reference Data Notebook
    ref_path = os.path.join(SCRIPT_DIR, "assets", "trains", "load_reference_data.ipynb")
    if "Load Train Reference Data" in existing:
        print("\nNotebook 'Load Train Reference Data' already exists - SKIP")
    else:
        print()
        create_notebook("Load Train Reference Data", ref_path,
                        "Download GTFS static timetable and load reference tables into TrainAnalysis KQL database",
                        token)

    # 3. Trip Updates Notebook
    tu_path = os.path.join(SCRIPT_DIR, "assets", "trains", "ingest_trip_updates.ipynb")
    if "Call Train Updates API" in existing:
        print("\nNotebook 'Call Train Updates API' already exists - SKIP")
    else:
        print()
        create_notebook("Call Train Updates API", tu_path,
                        "Retrieve real-time trip updates from Transport NSW Sydney Trains v2 API",
                        token)

    # Final check
    print("\n=== Verifying deployment ===")
    status, resp = fabric_api("GET", "items", token)
    enrichment_items = [i for i in resp.get("value", [])
                        if i["displayName"] in ("Stream_Train_Updates", "Load Train Reference Data", "Call Train Updates API")]
    for item in enrichment_items:
        print(f"  {item['type']:20s} {item['displayName']}")

    if len(enrichment_items) == 3:
        print("\nAll 3 enrichment components deployed successfully!")
    else:
        print(f"\nWarning: Expected 3 items, found {len(enrichment_items)}")

    print("\n=== NEXT STEPS ===")
    print("1. Open 'Load Train Reference Data' notebook -> set myapikey & kusto_uri -> Run All")
    print("2. Open Stream_Train_Updates -> Edit -> Add Custom Endpoint source -> copy connection string")
    print("3. Open 'Call Train Updates API' notebook -> set myapikey & connection_string -> Run")
    print("4. Add Eventhouse destination to Stream_Train_Updates -> TripUpdates table")


if __name__ == "__main__":
    main()
