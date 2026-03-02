# Real-Time Intelligence for Transport Analysis

> **Credit:** This project is based on the original work by [Ajit Ananth](https://github.com/ajananth) — [fabric-rti-transport-analysis](https://github.com/ajananth/fabric-rti-transport-analysis).
>
> **Ferry tracking** is based on the approach by [Francesco Fava](https://medium.com/@francescogiorgio.fava) — [Real-Time Ferry Tracking in Sydney Harbour with Microsoft Fabric](https://medium.com/@francescogiorgio.fava/real-time-ferry-tracking-in-sydney-harbour-with-microsoft-fabric-07bb2784ca50).
>
> **Sydney Trains tracking** is an original addition by [Sajit Gunawardane](https://github.com/sazit).

A solution for monitoring and analysing Sydney's public transport networks — **buses**, **ferries**, and **trains** — providing live hazard detection, route anomaly identification, and automated alerting for enhanced transportation safety and operational efficiency.

## 🚌⛴🚆 Objectives

This solution addresses critical challenges in urban transportation management across three transport modes:

### **Safety & Security**
- **Real-time hazard monitoring**: Continuous tracking of live traffic incidents, road closures, and safety hazards
- **Proximity detection**: Automated detection of buses approaching hazardous areas

### **Operational Excellence**
- **Route anomaly detection**: Identification of unusual bus behaviour patterns and route deviations
- **Performance monitoring**: Real-time alerts for bus route deviations
- **Train line monitoring**: Speed, direction, and stationary train detection across all Sydney Trains lines

### **Service Quality**
- **Live visibility**: Real-time dashboards showing current bus, ferry, and train positions
- **Pattern analysis**: Understanding normal vs. abnormal operational patterns
- **Fleet status**: Movement breakdown (moving, at station, approaching) across all modes

## 🏗️ Solution Architecture

![Task Flow](images/task%20flow/task_flow.png)

The solution contains five key stages:

### 1. **Data Ingestion** 📡
- **Call Buses API** (`assets/buses/`): Retrieves real-time bus positions via GTFS v1
- **Call Hazards API** (`assets/hazards/`): Fetches live hazard and incident data (GeoJSON)
- **Call Ferry API** (`assets/ferry/`): Retrieves real-time Sydney Ferry positions via GTFS v1
- **Call Trains API** (`assets/trains/`): Retrieves real-time Sydney Trains positions via **GTFS v2** (v1 deprecated May 2025)
- **Polling Frequency**: 15-second intervals for all data sources

### 2. **Real-Time Streaming** 🌊
- **Stream_Bus_Loc**: Bus position data processing
- **Stream_Live_Info**: Hazard/incident information processing
- **Stream_Ferry_Loc**: Ferry position data processing
- **Stream_Train_Loc**: Train position data processing

### 3. **Data Storage** 🗄️
- **TransportAnalysis** (Eventhouse): Bus positions (`buses` table) and hazard data (`hazards` table)
- **FerryAnalysis** (Eventhouse): Ferry positions (`Ferry` table)
- **TrainAnalysis** (Eventhouse): Train positions (`Trains` table) with rich fields — route line, direction, stop, speed, bearing, movement status

### 4. **Analytics & Processing** 🔍
- **Proximity Analysis**: Geospatial calculations between buses and hazards
- **Anomaly Detection**: Machine learning algorithms identifying unusual route patterns
- **Stationary Train Detection**: Identifying trains stopped > 2 minutes (potential delays)
- **Line Performance**: Speed comparisons across T1-T9 train lines

### 5. **Visualisation & Alerting** 📊
- **Live Dashboards**: Real-time maps and visualisations per transport mode
- **Automated Alerts**: Threshold-based notifications and warnings

## 🛠️ Technology Stack

This solution is built entirely using **Microsoft Fabric Real-Time Intelligence**, consuming data from the **Transport NSW Open Data API**.

### **Data Sources**
| Mode | API | Endpoint | Format |
|------|-----|----------|--------|
| Buses | v1 | `/v1/gtfs/vehiclepos/regionbuses/sydneysurrounds` | GTFS Protobuf |
| Hazards | v1 | `/v1/live/hazards/incident/open` | GeoJSON |
| Ferries | v1 | `/v1/gtfs/vehiclepos/ferries/sydneyferries` | GTFS Protobuf |
| Trains | **v2** | `/v2/gtfs/vehiclepos/sydneytrains` | GTFS Protobuf |

### **Microsoft Fabric Components**
- **Real-Time Intelligence (RTI)**: Core platform for streaming analytics
- **Notebooks**: Spark-based data processing for ingestion
- **Eventstreams**: Real-time data ingestion and processing
- **Eventhouse**: High-performance KQL database for time-series analytics
- **Real-time Dashboard & Maps**: Interactive real-time dashboards and reporting
- **Anomaly Detection**: Built-in anomaly detection capabilities
- **Activator**: Real-time alerting and monitoring

## 📋 Prerequisites

Before implementing this solution, ensure you have:

- A Microsoft Fabric capacity
- Basic understanding of streaming analytics concepts

## 📚 Tutorial Structure

This repository contains a complete step-by-step tutorial covering:

1. **[Environment Setup](./docs/01-environment-setup.md)** - Fabric workspace configuration and prerequisites
2. **[API Integration](./docs/02-api-integration.md)** - Connecting to public transport authority data sources and Eventstream configuration
3. **[Data Storage Configuration](./docs/03-data-storage.md)** - Implementing Eventhouse for real-time data storage
4. **[Hazard Proximity Analysis](./docs/04-hazard-proximity-analysis.md)** - Real-time geospatial analysis and RTI dashboards for monitoring buses and hazards
5. **[Bus Route Anomaly Detection](./docs/05-bus-route-anomaly-detection.md)** - Native Fabric RTI anomaly detection for identifying unusual bus route patterns
6. **[Automated Alerting](./docs/06-automated-alerting.md)** - Real-time Teams notifications for bus route anomalies using Activator

## 📂 Project Structure

```
assets/
├── buses/          # Bus position ingestion (Ajit Ananth)
│   └── ingest.ipynb
├── hazards/        # Hazard data ingestion (Ajit Ananth)
│   └── ingesthz.ipynb
├── ferry/          # Ferry position ingestion (based on Francesco Fava)
│   └── ingest_ferry.ipynb
└── trains/         # Sydney Trains position ingestion (Sajit Gunawardane)
    └── ingest_trains.ipynb

deploy_fabric.ps1   # Deploy bus/hazard components
deploy_ferry.ps1    # Deploy ferry components
deploy_trains.ps1   # Deploy train components
docs/               # Step-by-step tutorial
```

## 🚀 Getting Started

Ready to build your own real-time transport intelligence solution? The detailed tutorial begins with [Environment Setup](docs/01-environment-setup.md), where we'll configure your Microsoft Fabric workspace and prepare for data ingestion.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to improve this solution.
