# Environment Setup

This guide walks you through setting up your Microsoft Fabric workspace with Real-Time Intelligence capabilities and creating the task flow components for the transport analysis solution.

## 📋 Prerequisites

Before beginning, ensure you have:

- **Microsoft Fabric capacity** (any suitable F SKU capacity)
- **Workspace Admin permissions** to create and configure workspaces
- **Web browser** (Microsoft Edge or Chrome recommended)

## 🏗️ Step 1: Create Microsoft Fabric Workspace

### 1.1 Access Microsoft Fabric Portal

1. Navigate to [Microsoft Fabric Portal](https://fabric.microsoft.com)
2. Sign in with your organisational account
3. If prompted, select your tenant/organisation

### 1.2 Create New Workspace

1. Click **"Workspaces"** in the left navigation panel
2. Select **"+ New workspace"**
3. Configure workspace settings:
   - **Name**: `Transport RTI Analysis` (or your preferred name)
   - **Description**: `Real-time intelligence for transport network monitoring`
   - **Advanced settings**:
     - **Capacity**: Select your available Fabric capacity
4. Click **"Apply"** to create the workspace

### 1.3 Access Real-Time Intelligence Features

1. Within your new workspace, click **"+ New"**
2. You should see all Real-Time Intelligence items available:
   - **Notebook**
   - **Eventstream**
   - **Eventhouse**
   - **Real-time Dashboard**
   - **Data Activator**

## 🏗️ Step 2: Understand the Task Flow Architecture

The solution follows a structured data pipeline with five key components:

### 2.1 Task Flow Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Call Buses    │──▶│  Stream Bus Loc │───▶│                 │──▶│     Analyse     │
│      API        │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    │      Store      │    └─────────────────┘
                                              │   (Eventhouse)  │                       
┌─────────────────┐    ┌─────────────────┐    │                 │                       
│  Call Hazards   │──▶│ Stream Live Info│───▶│                 │                       
│      API        │    │                 │    │                 │                       
└─────────────────┘    └─────────────────┘    └─────────────────┘                       
```

### 2.2 Component Functions

The tutorial will guide you through creating:

1. **Call Buses API** (Notebook) - Data ingestion from transport APIs
2. **Call Hazards API** (Notebook) - Hazard data collection
3. **Stream Bus Loc** (Eventstream) - Real-time vehicle position processing  
4. **Stream Live Info** (Eventstream) - Hazard information streaming
5. **Store** (Eventhouse) - Central data repository
6. **Analyse** (Dashboard) - Visualisation and analytics

> **Note**: These components will be created and configured in subsequent tutorial steps.

## 🏗️ Step 3: Create Task Flow

Now we'll create a visual task flow in your Fabric workspace to plan and organise the solution components using Fabric's built-in task flow designer.

### 3.1 Open Task Flow Designer

1. Navigate to your **Transport RTI Analysis** workspace
2. Ensure you're in **List view** (select the List view icon if needed)
3. You'll see the workspace split into two sections:
   - **Task flow canvas** (top) - where you'll build your visual workflow
   - **Items list** (bottom) - showing workspace components
4. A moveable separator bar allows you to adjust the size of each view

### 3.2 Create Custom Task Flow

Since our solution has a specific architecture, we'll build a custom task flow from scratch:

1. In the empty task flow area, click **"Add a task"**
2. Select **"General"** as the task type for the first component
3. A task card appears on the canvas with a task details pane on the side

### 3.3 Build the Transport Analysis Task Flow

Create the following tasks in sequence, using the appropriate task categories as shown in the solution:

**Task 1: Call Buses API**
1. Click **"Edit"** in the task details pane
2. **Task Category**: Select **"General"** (grey icon)
3. **Name**: `Call Buses API`  
4. **Description**: `Retrieve real-time vehicle position data from transport authority APIs`
5. Click **"Save"**

**Task 2: Call Hazards API**
1. Click on blank canvas area, then **"Add a task"** → **"General"**
2. **Task Category**: Select **"General"** (grey icon)
3. **Name**: `Call Hazards API`
4. **Description**: `Fetch live hazard and incident data from traffic management systems`

**Task 3: Stream Bus Loc**
1. Add another task: **"Add a task"** → **"Get data"**
2. **Task Category**: Select **"Get data"** (green icon)
3. **Name**: `Stream Bus Loc`
4. **Description**: `Process live vehicle position data through Eventstream`

**Task 4: Stream Live Info**
1. Add another task: **"Add a task"** → **"Get data"**
2. **Task Category**: Select **"Get data"** (green icon)  
3. **Name**: `Stream Live Info`
4. **Description**: `Process hazard and incident information through Eventstream`

**Task 5: Store**
1. Add another task: **"Add a task"** → **"Store data"**
2. **Task Category**: Select **"Store data"** (blue icon)
3. **Name**: `Store`
4. **Description**: `Central data repository using Eventhouse for analytics`

**Task 6: Analyse**
1. Add final task: **"Add a task"** → **"Visualize data"**
2. **Task Category**: Select **"Visualize data"** (yellow/orange icon)
3. **Name**: `Analyse`
4. **Description**: `Real-time visualisation and analytics dashboard`

### 3.4 Connect the Tasks

Create logical connections between tasks to show the data flow:

1. **Hover over the Call Buses API task** until connection points appear
2. **Click and drag** from the right connection point to connect to **Stream Bus Loc**
3. **Connect Call Hazards API** to **Stream Live Info** the same way
4. **Connect both Stream Bus Loc and Stream Live Info** to **Store**
5. **Connect Store** to **Analyse**

Your completed task flow should match the solution architecture with:
- **Grey tasks** (General): API data collection components
- **Green tasks** (Get data): Real-time streaming and data ingestion  
- **Blue task** (Store data): Central data repository
- **Yellow/Orange task** (Visualize data): Analytics and dashboard

The visual flow shows: `API Collection → Data Streaming → Data Storage → Analytics`

### 3.5 Update Task Flow Details

1. **Click on blank canvas area** to deselect all tasks
2. The side pane shows task flow details with default name
3. Click **"Edit"** and update:
   - **Name**: `Transport RTI Analysis Pipeline`
   - **Description**: `Real-time intelligence pipeline for transport network monitoring and hazard detection`
4. Click **"Save"**

### 3.6 Arrange Tasks on Canvas

Drag tasks to create a clean, logical layout that clearly shows the data pipeline flow from left to right:
- **Left side**: API data ingestion tasks
- **Centre**: Streaming processing tasks  
- **Right side**: Storage and analysis tasks

### 3.7 Linking Items to Tasks

As you progress through the subsequent tutorial steps, you'll create actual Fabric items (Notebooks, Eventstreams, Eventhouse, Dashboards, etc.) that correspond to each task in your flow. Remember to assign these newly created items to their respective tasks in the task flow to maintain organisation and provide visual tracking of your solution's implementation progress.

---

## Related Documentation

- [Microsoft Fabric Workspaces](https://learn.microsoft.com/en-us/fabric/fundamentals/create-workspaces)
- [Real-Time Intelligence Overview](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/)
- [Task Flow Designer](https://learn.microsoft.com/en-us/fabric/fundamentals/task-flow)

---

## 🚀 Next Steps

Your environment is now ready! The next step is to configure API integration to begin ingesting real-time transport data.

---

## Tutorial Navigation

**→ Next:** [Tutorial 2: API Integration](./02-api-integration.md)