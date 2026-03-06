# Real-Time Intelligence for Transport Analysis

> **Credit:** This project is based on the original work by [Ajit Ananth](https://github.com/ajananth) — [fabric-rti-transport-analysis](https://github.com/ajananth/fabric-rti-transport-analysis).
>
> **Ferry tracking** is based on the approach by [Francesco Fava](https://medium.com/@francescogiorgio.fava) — [Real-Time Ferry Tracking in Sydney Harbour with Microsoft Fabric](https://medium.com/@francescogiorgio.fava/real-time-ferry-tracking-in-sydney-harbour-with-microsoft-fabric-07bb2784ca50).
>
> **Sydney Trains tracking** is an original addition by [Sajit Gurubacharya](https://github.com/sazit).

A Microsoft Fabric Real-Time Intelligence solution for monitoring and analysing Sydney's public transport networks — **buses**, **ferries**, and **trains** — with live hazard detection, route anomaly identification, and automated alerting.

## Architecture

```
Transport NSW APIs ──► Fabric Notebooks (15s polling)
                            │
                            ▼
                       Eventstreams
                    ┌───────┼───────┐
                    ▼       ▼       ▼
              Stream_    Stream_  Stream_    Stream_
              Bus_Loc   Live_Info Ferry_Loc  Train_Loc
                    │       │       │           │
                    ▼       ▼       ▼           ▼
                Eventhouses (KQL Databases)
              ┌─────────┬──────────┬────────────┐
              ▼         ▼          ▼            ▼
          Transport  (hazards)  Ferry       Train
          Analysis    table    Analysis    Analysis
                    │
                    ▼
            KQL Dashboards & Reports
          ┌─────────┬──────────┬────────────┐
          ▼         ▼          ▼            ▼
       Transport  Hazard    Ferry      Sydney Trains
       Analysis  Proximity Dashboard   Analysis + Live Report
```

## Fabric Workspace — RTI-Transport

This repo is synced with the **RTI-Transport** Fabric workspace via Git Integration. All items below are managed as code:

### Eventhouses
| Eventhouse | KQL Database | Data |
|---|---|---|
| TransportAnalysis | TransportAnalysis | Bus positions + hazard incidents |
| FerryAnalysis | FerryAnalysis | Sydney Ferry positions |
| TrainAnalysis | TrainAnalysis | Sydney Trains positions, speed, bearing, status |
| Monitoring Eventhouse | Monitoring KQL database | System health monitoring |

### Eventstreams
| Stream | Source |
|---|---|
| Stream_Bus_Loc | Real-time bus positions (GTFS v1) |
| Stream_Live_Info | Live hazard/incident data (GeoJSON) |
| Stream_Ferry_Loc | Ferry positions (GTFS v1) |
| Stream_Train_Loc | Train positions (GTFS v2) |
| Monitoring_Eventstream | Workspace monitoring |

### Notebooks
| Notebook | API Endpoint | Format |
|---|---|---|
| Call Buses API | `/v1/gtfs/vehiclepos/regionbuses/sydneysurrounds` | GTFS Protobuf |
| Call Hazards API | `/v1/live/hazards/incident/open` | GeoJSON |
| Call Ferry API | `/v1/gtfs/vehiclepos/ferries/sydneyferries` | GTFS Protobuf |
| Call Trains API | `/v2/gtfs/vehiclepos/sydneytrains` | GTFS Protobuf |

### Dashboards & Reports
- **TransportAnalysis** — bus event counts, real-time position map
- **HazardsAnalysis** — hazard proximity detection (20km radius), impacted buses
- **FerryDashboard** — live ferry positions across Sydney Harbour
- **SydneyTrainsAnalysis** — train line performance, speed, stationary detection
- **Sydney Trains Live Report** — Power BI report with semantic model

### AI
- **Train Master Agent** — Fabric Data Agent for natural language queries over train data

## Data Sources

All data is sourced from the [Transport NSW Open Data API](https://opendata.transport.nsw.gov.au/) with 15-second polling intervals.

| Mode | API Version | Key Data Points |
|---|---|---|
| Buses | v1 | name, lat/long, speed |
| Hazards | v1 | name, lat/long, type |
| Ferries | v1 | name, lat/long, destination |
| Trains | **v2** | id, route, lat/long, speed, bearing, direction, stop, movement status |

## Development Workflow

This repo uses **Fabric Git Integration** for bidirectional sync between the Fabric workspace and GitHub:

```
┌─────────────────────┐         ┌─────────────────────┐         ┌──────────────┐
│   Fabric Portal     │◄───────►│   GitHub Repo       │◄───────►│  VS Code     │
│   RTI-Transport     │  sync   │   main branch       │  pull/  │  Local Dev   │
│   workspace         │         │   /                  │  push   │              │
└─────────────────────┘         └─────────────────────┘         └──────────────┘
```

- **Fabric → Git**: Changes made in the Fabric portal (edit a notebook, update a dashboard) are committed to GitHub
- **Git → Fabric**: Pushes to `main` from VS Code sync back into the workspace
- **Local editing**: Clone the repo, edit with VS Code + Copilot, push to GitHub, Fabric auto-syncs

### Repo Structure

```
/                            ← Fabric Git Integration root (synced items)
├── *.Eventhouse/            ← Eventhouse definitions
├── *.Eventstream/           ← Eventstream configs
├── *.Notebook/              ← Spark notebooks
├── *.KQLDashboard/          ← KQL dashboard layouts + queries
├── *.Report/                ← Power BI reports
├── *.DataAgent/             ← Fabric Data Agent config
├── README.md                ← This file
└── _deploy/                 ← Legacy deploy scripts (not synced by Fabric)
    ├── deploy_fabric.ps1
    ├── deploy_ferry.ps1
    ├── deploy_trains.ps1
    ├── assets/              ← Original notebook .ipynb files
    ├── docs/                ← Step-by-step setup guides
    └── images/              ← Architecture diagrams + screenshots
```

## Setup

1. Register for a [Transport NSW API key](https://opendata.transport.nsw.gov.au/)
2. Ensure a Fabric capacity is available (any F SKU)
3. Configure each notebook with your API key and Eventstream connection string
4. Connect the Fabric workspace to this repo via **Workspace Settings → Git Integration**

## Legacy Deploy Scripts

The original PowerShell deployment scripts that created the workspace items via the Fabric REST API are preserved in [`_deploy/`](_deploy/). These are superseded by Git Integration — the actual Fabric item definitions now live in the repo root.
