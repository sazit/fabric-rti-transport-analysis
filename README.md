# Real-Time Intelligence for Transport Analysis

> **Credit:** This project is based on the original work by [Ajit Ananth](https://github.com/ajananth) — [fabric-rti-transport-analysis](https://github.com/ajananth/fabric-rti-transport-analysis).

A solution for monitoring and analysing public transport networks, providing live hazard detection, route anomaly identification, and automated alerting for enhanced transportation safety and operational efficiency.

## 🚌 Objectives

This solution addresses critical challenges in urban transportation management:

### **Safety & Security**
- **Real-time hazard monitoring**: Continuous tracking of live traffic incidents, road closures, and safety hazards
- **Proximity detection**: Automated detection of buses approaching hazardous areas

### **Operational Excellence**
- **Route anomaly detection**: Identification of unusual bus behaviour patterns and route deviations
- **Performance monitoring**: Real-time alerts for bus route deviations

### **Service Quality**
- **Live visibility**: Real-time dashboards showing current bus positions and service status
- **Pattern analysis**: Understanding normal vs. abnormal operational patterns

## 🏗️ Solution Architecture

![Task Flow](images/task%20flow/task_flow.png)

The solution contains five key stages:

### 1. **Data Ingestion** 📡
- **Call Transport API**: Retrieves real-time vehicle position data
- **Call Hazards API**: Fetches live hazard and incident data
- **Polling Frequency**: Configurable intervals (15-second default) for both data sources

### 2. **Real-Time Streaming** 🌊
- **Stream Vehicle Locations**: Stream processing live vehicle position data
- **Stream Live Hazard Info**: Stream processing hazard and incident information

### 3. **Data Storage** 🗄️
- **Eventhouse**: High-performance analytics database optimised for time-series and streaming data
- **Historical retention**: Long-term storage of vehicle positions and hazard data for trend analysis

### 4. **Analytics & Processing** 🔍
- **Proximity Analysis**: Geospatial calculations between buses and hazards
- **Anomaly Detection**: Machine learning algorithms identifying unusual route patterns

### 5. **Visualisation & Alerting** 📊
- **Live Dashboards**: Real-time maps and visualisations
- **Automated Alerts**: Threshold-based notifications and warnings

## 🛠️ Technology Stack

This solution is built entirely using **Microsoft Fabric Real-Time Intelligence**, providing a comprehensive platform for streaming analytics, real-time data processing, and intelligent monitoring.

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

## 🚀 Getting Started

Ready to build your own real-time transport intelligence solution? The detailed tutorial begins with [Environment Setup](docs/01-environment-setup.md), where we'll configure your Microsoft Fabric workspace and prepare for data ingestion.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to improve this solution.
