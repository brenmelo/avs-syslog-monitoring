# AVS Syslog Monitoring — Workbook & Alerts

Pre-built Azure Monitor **Workbook** (~40 panels) and **14 syslog alert rules** for monitoring [Azure VMware Solution (AVS)](https://learn.microsoft.com/en-us/azure/azure-vmware/) — running against the `AVSSyslog` Log Analytics table.

### The core solution

- **Workbook** — Severity distribution, per-severity drill-downs (Emergency/Alert/Critical/Error) with explanations and grouped Top Repeated Messages, event-specific views (host failures, VM changes, DNS, DFW, maintenance, role/permission changes), per-host health heatmap, and syslog ingestion pipeline health.
- **14 alert rules** — Scheduled query alerts across three severity tiers:
  - **Sev 0** — Emergency, Alert, host connection lost, host shutdown, syslog ingestion heartbeat
  - **Sev 1** — Critical, VM disconnected/removed, DNS failures, role & permission changes
  - **Sev 2** — Error, DFW spikes, host maintenance mode, VM guest reboots
  - *(Critical alert excludes ~99% of Microsoft-managed vSAN/control-plane noise from `vsand`, `clomd`, `clomd-whatif`, `etcd` — see [Known Noisy Events](#-known-noisy-events--exclusion-filters).)*

### Also included

- **4 Azure Service Health alerts** — Activity-log alerts filtered to AVS for Service Issues, Planned Maintenance (ESXi/vCenter/NSX/vSAN upgrades), Health Advisories, and Security Advisories (VMSAs/CVEs). Covers the Microsoft side of the [shared responsibility model](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/azure-vmware/manage).
- **Guided deployment wizards** — `createUiDefinition` portal experiences with action group pickers, alert toggles, threshold sliders, and region selection. One-click **Deploy to Azure** buttons for each artifact.
- **Operational guidance** — Severity model explanation, action group strategy across 10 notification types (Email, SMS, Teams, Webhook, ITSM, Logic App, Function, Runbook, etc.), and known noisy events that are safely filtered.

> **✅ Validated against Microsoft docs:** All event-specific KQL patterns (host shutdown, VM disconnected, DNS failures, DFW logs, role changes, maintenance mode, etc.) match Microsoft's official [Queries for the AVSSyslog table](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/queries/avssyslog) reference verbatim.

---

## 📑 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Deploy the Workbook](#1-deploy-the-workbook)
3. [Deploy the AVS Syslog Alert Rules](#2-deploy-the-avs-syslog-alert-rules)
4. [Deploy Azure Service Health Alerts](#3-deploy-azure-service-health-alerts-recommended)
5. [Alert Rules Reference](#-alert-rules-reference)
6. [Action Group Routing](#-action-group-routing)
7. [Threshold Tuning Guide](#-threshold-tuning-guide)
8. [Alert Naming Convention](#-alert-naming-convention)
9. [Repository Files](#-repository-files)
10. [Deployment Parameters — Alert Template](#-deployment-parameters--alert-template)
11. [Known Noisy Events & Exclusion Filters](#-known-noisy-events--exclusion-filters)
12. [Exploration Queries](#-exploration-queries)
13. [References](#-references)

---

## 📋 Prerequisites

| Requirement | Details |
|---|---|
| **AVS private cloud** | With a [Diagnostic Setting](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs) that sends the **Syslog** category to a Log Analytics workspace. |
| **Log Analytics workspace** | The workspace that receives `AVSSyslog` data. |
| **Action Group(s)** | At least one [Action Group](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups) for alert notifications. Required only for alert deployment. |

### Configure AVS Syslog Forwarding

Before deploying, your AVS private cloud must be sending syslog data to a Log Analytics workspace:

1. In the Azure portal, navigate to your **Azure VMware Solution** private cloud.
2. Go to **Diagnostic settings** → **+ Add diagnostic setting**.
3. Check the **VMware Syslog** category (this includes vCenter, ESXi, vSAN, NSX, and firewall logs).
4. Under **Destination details**, select **Send to Log Analytics workspace** and choose your workspace.
5. Click **Save**.

Verify data is flowing after a few minutes:

```kql
AVSSyslog
| take 10
```

> For full details, see [Configure VMware syslogs for Azure VMware Solution](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs).

---

## 📊 1. Deploy the Workbook

The workbook gives you real-time dashboards for severity distribution, event-specific monitoring, host health, and pipeline status — start here.

### Option A — One-click Deploy

[![Deploy Workbook to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2Favs-syslog-workbook-deploy-template.json)

1. Click the button above.
2. Select your **Subscription**, **Resource Group**, and **Region**.
3. Optionally change the workbook display name (default: `AVS Syslog Monitoring`).
4. Click **Review + create** → **Create**.
5. Open the workbook and select your **Log Analytics workspace** from the dropdown inside.

### Option B — Manual Import (Azure Portal)

1. Go to **Monitor → Workbooks → + New**.
2. Click the **Advanced Editor** icon (`</>`).
3. Delete any existing JSON in the editor.
4. Paste the full contents of [`avs-syslog-workbook-gallery.json`](avs-syslog-workbook-gallery.json).
5. Click **Apply**.
6. Click **Save** (or **Save As**), choose your resource group and location.

### Option C — Azure CLI

```bash
# Deploy the workbook ARM template
az deployment group create \
  --resource-group <your-rg> \
  --template-file avs-syslog-workbook-deploy-template.json
```

### Workbook Sections

Once deployed, the workbook includes:

| Section | What It Shows |
|---|---|
| **Overview** | Severity distribution tiles, pie chart, top event sources by AppName |
| **Part 1 — Severity-Based** | Time series and detail grids for Emergency, Alert, Critical, Error events |
| **Part 2 — Event-Specific** | Summary tiles and grids for host failures, VM changes, DNS, DFW, maintenance, role changes |
| **Host Health Overview** | Per-host heatmap and trend of high-impact events |
| **Data Pipeline Health** | Syslog ingestion heartbeat tile and volume chart |

---

## 🚨 2. Deploy the AVS Syslog Alert Rules

### Before You Begin — Create an Action Group

Alert rules require at least one **Action Group** to define who gets notified and how. If you don't have one yet, create one before deploying alerts.

**Create an Action Group:** Go to **Monitor → Alerts → Action groups → + Create**.

| Notification Type | Use Case | Setup |
|---|---|---|
| **Email** | Direct email to on-call engineers or distribution lists | Add email addresses under the **Notifications** tab |
| **SMS** | Urgent alerts to mobile phones | Add phone numbers under **Notifications** |
| **Azure mobile app** | Push notifications to the Azure app on your phone | Enable under **Notifications** → Azure app push |
| **Voice call** | Phone call for critical after-hours alerts | Add phone numbers under **Notifications** |
| **Microsoft Teams** | Post alerts to a Teams channel for team visibility | Under **Actions** → select **Microsoft Teams** and pick the channel ([docs](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups#microsoft-teams)) |
| **Webhook** | Integrate with ticketing systems (ServiceNow, PagerDuty, Jira, etc.) | Under **Actions** → add a **Webhook** with the endpoint URL from your ITSM tool |
| **ITSM Connector** | Bi-directional integration with ServiceNow, System Center, etc. | Under **Actions** → select **ITSM** ([docs](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/itsmc-overview)) |
| **Logic App** | Custom workflows — auto-create tickets, enrich alerts, notify Slack, etc. | Under **Actions** → select **Logic App** and choose your workflow |
| **Azure Function** | Run custom code on alert (e.g., auto-remediation scripts) | Under **Actions** → select **Azure Function** |
| **Automation Runbook** | Execute PowerShell/Python runbooks for automated response | Under **Actions** → select **Automation Runbook** |

**Recommended strategy for AVS syslog monitoring:**

- **Minimum setup** — One action group with email notifications, used across all severity tiers.
- **Tiered setup** — Three action groups (one per severity tier) with escalating urgency:
  - **Sev 0** (Emergency/Alert/Host-down/Heartbeat) → Email + SMS + Voice call + Teams channel
  - **Sev 1** (Critical/VM/DNS/Role changes) → Email + Teams channel
  - **Sev 2** (Error/DFW/Maintenance/Guest Reboot) → Email only (or Teams)
- **Enterprise setup** — Action groups with webhook or ITSM integration to automatically create tickets in ServiceNow, PagerDuty, or Jira. Use Logic Apps for custom enrichment workflows (e.g., auto-tagging, Slack notifications, or runbooks for automated response).

> **Reference:** [Create and manage action groups](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups) | [IT Service Management Connector](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/itsmc-overview)

### Option A — Deploy from the Workbook (recommended)

If you deployed the workbook in Step 1, open it and click the **Deploy to Azure** button at the top of the workbook:

![Deploy from Workbook](images/workbook-deploy-button.png)

1. Open your deployed workbook: **Monitor → Workbooks → AVS Syslog Monitoring**.
2. Click the **Deploy to Azure** button shown above.
3. A guided wizard walks you through:
   - **Basics** — Subscription, resource group, region, Log Analytics workspace.
   - **Action Groups** — Select existing action groups from dropdowns for Severity 0, 1, and 2 (leave empty to skip a tier).
   - **Select Alerts** — Check or uncheck each of the 14 alert rules.
   - **Thresholds** — Sliders for volume-based alerts (Error, DNS, DFW).
4. Click **Review + create** → **Create**.

### Option B — One-click Deploy (standalone)

[![Deploy Alerts to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2Favs-syslog-alerts-deploy-template.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2FcreateUiDefinition.json)

1. Click the button above (opens the same wizard directly without needing the workbook).
2. Follow the same guided wizard steps as Option A.
3. Click **Review + create** → **Create**.

### Option C — Azure CLI (all alerts at once)

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file avs-syslog-alerts-deploy-template.json \
  --parameters workspaceResourceId="<workspace-resource-id>" \
               actionGroupIdSev0="<action-group-resource-id>" \
               actionGroupIdSev1="<action-group-resource-id>" \
               actionGroupIdSev2="<action-group-resource-id>"
```

### Option D — Manual Alert Creation (Azure Portal)

Create individual alert rules from **Monitor → Alerts → + Create → Alert rule**:

1. **Scope** — Select your Log Analytics workspace.
2. **Condition** — Choose **Custom log search**, paste the KQL query from the table below.
3. **Measurement** — Aggregation type: **Count**, Threshold: as noted.
4. **Evaluation** — Check every **5 minutes**, lookback period **15 minutes** (30 min for Heartbeat).
5. **Actions** — Attach your Action Group.
6. **Details** — Set the name, severity, and description.
7. **Review + create**.

Repeat for each alert you want. The full KQL queries are listed below.

---

## 🏥 3. Deploy Azure Service Health Alerts (recommended)

Syslog alerts monitor what's happening **inside** your AVS environment. Azure Service Health alerts monitor what **Microsoft is doing** — service outages, planned maintenance (ESXi/vCenter/NSX upgrades), health advisories, and security advisories (VMSAs, CVEs). Both are needed for complete monitoring.

### Why Service Health Alerts Matter for AVS

Microsoft is responsible for patching, upgrading, and maintaining the AVS infrastructure ([shared responsibility](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/azure-vmware/manage)). Service Health is how Microsoft communicates:

- **Service Issues** — Outages or degradations affecting your private cloud
- **Planned Maintenance** — ESXi, vCenter, NSX, and vSAN upgrades (may cause brief VM connectivity interruptions during NSX upgrades)
- **Health Advisories** — Actions recommended (e.g., enable compression, update VMware Tools)
- **Security Advisories** — VMSAs and CVEs affecting AVS (e.g., VMSA-2025-0013, CVE-2025-22224)

Many items in the [Azure VMware Solution known issues](https://learn.microsoft.com/en-us/azure/azure-vmware/azure-vmware-solution-known-issues) page are first communicated via Service Health.

### Option A — One-click Deploy

[![Deploy Service Health Alerts](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2Favs-service-health-alert-template.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2FcreateUiDefinition-service-health.json)

1. Click the button above.
2. Select your **Subscription**, **Resource Group**, and **Region**.
3. Select an **existing action group** from the dropdown (create one first if needed — see [Section 2](#before-you-begin--create-an-action-group)).
4. Check or uncheck which notification types to monitor (all enabled by default):
   - Service Issues
   - Planned Maintenance
   - Health Advisories
   - Security Advisories
5. Click **Review + create** → **Create**.

### Option B — Azure Portal (manual)

1. Go to **Monitor → Service Health → Health alerts → + Create activity log alert**.
2. Under **Scope**, select your subscription.
3. Under **Condition**:
   - **Services** → select **Azure VMware Solution**
   - **Event types** → check all: Service issue, Planned maintenance, Health advisory, Security advisory
4. Under **Actions**, select or create an action group.
5. Under **Details**, name the alert (e.g., `AVS-ServiceHealth-Alert`).
6. Click **Review + create** → **Create**.

### Option C — Azure CLI

```bash
# Create a Service Health alert for AVS service issues
az monitor activity-log alert create \
  --name "AVS-ServiceHealth-ServiceIssues" \
  --resource-group <your-rg> \
  --condition category=ServiceHealth \
  --condition-service "Azure VMware Solution" \
  --action-group <action-group-resource-id> \
  --description "AVS service issue alert"
```

> **Reference:** [Create Service Health alerts using ARM template](https://learn.microsoft.com/en-us/azure/service-health/alerts-activity-log-service-notifications-arm) | [Create Service Health alerts using the Azure portal](https://learn.microsoft.com/en-us/azure/service-health/alerts-activity-log-service-notifications-portal)

---

## 📚 Alert Rules Reference

### Evaluation Window & Frequency

All alert rules use an **evaluation frequency of 5 minutes** with a **lookback window of 15 minutes** (except the Ingestion Heartbeat alert, which uses a 30-minute window). These are the same values used by the **Deploy to Azure** button — no adjustment is needed after deployment.

**Why 15 minutes?**
- A 15-minute window with a 5-minute evaluation frequency means each check scans the last 15 minutes of data. This provides three overlapping evaluation cycles per window, which reduces the chance of missing a transient event that arrives near an evaluation boundary.
- It also smooths out short bursts — a single stray error won't immediately trigger threshold-based alerts (Error, DNS, DFW), but a sustained pattern within 15 minutes will.
- The Heartbeat alert uses 30 minutes because brief ingestion delays (a few minutes) are normal; only a prolonged gap signals a real pipeline problem.

**Why not a shorter window (e.g. 1 or 5 minutes)?**
- AVS syslog data flows through multiple stages before it becomes queryable: AVS private cloud → Diagnostic Setting → Log Analytics ingestion pipeline → `AVSSyslog` table. This typically takes **3–10 minutes**, depending on the Azure services involved ([Microsoft documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-ingestion-time#factors-affecting-latency)).
- A 1-minute window would scan a time range where the data hasn't arrived yet, causing **missed alerts**.
- A 5-minute window works in ideal conditions but leaves no buffer for ingestion delays — if data takes 6 minutes to arrive, the event falls outside the window.
- The 15-minute window is resilient to the full documented ingestion latency range, with no downside for `> 0` threshold alerts. **Detection speed is controlled by the 5-minute frequency, not the window** — the window only affects how far back each evaluation scans.

**Should you adjust it?**
- For most environments, the defaults work well. You can adjust them after deployment in **Monitor → Alerts → Alert rules → Edit**:
  - **Shorter window (e.g. 5 min)** — Faster alerting, but more sensitive to noise and one-off spikes.
  - **Longer window (e.g. 30 min)** — More tolerant of transient spikes, but slower to detect sustained issues.
- If you create alerts manually (Option D), use the values in the tables below, or adjust to match your operational requirements.

### Understanding Syslog Severity Levels

Syslog uses eight standard severity levels defined in [RFC 5424](https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1). This solution focuses on **Severity 0–3** as high-impact events that warrant alerting:

| Level | Keyword | Meaning | Examples | Alerting Strategy |
|:---:|---|---|---|---|
| **0** | `emerg` / `emergency` | System is unusable | Kernel panic, complete storage failure, host PSOD | **Alert immediately** — any occurrence |
| **1** | `alert` | Immediate action required | Hardware failure requiring replacement, HA failover triggered | **Alert immediately** — any occurrence |
| **2** | `crit` / `critical` | Critical condition | vSAN object inaccessible, disk group decommissioned, ESXi host disconnected | **Alert immediately** — excludes known noisy patterns |
| **3** | `err` / `error` | Error condition | SOAP timeouts, NTP sync failures, snapshot consolidation errors | **Optional** — threshold-based (can be noisy) |
| 4 | `warn` / `warning` | Warning — developing issue | High memory/CPU usage, certificate expiration approaching | Monitor in workbook (no alert by default) |
| 5 | `notice` | Normal but noteworthy | User login events, configuration changes, VM power state changes | Monitor in workbook |
| 6 | `info` | Informational | Routine heartbeats, backup completion, scheduled tasks | Monitor in workbook |
| 7 | `debug` | Debug-level detail | Verbose API tracing, internal state dumps | Monitor in workbook |

> **Shared Responsibility:** In Azure VMware Solution, Microsoft manages the underlying infrastructure (ESXi hosts, vSAN, NSX, vCenter). Events from platform components like `vsand`, `hostd`, `vpxd`, and `nsxd` are **Microsoft's responsibility** to address. Customers are responsible for monitoring and responding to events related to their workload VMs. See [Azure VMware Solution management](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/azure-vmware/manage) and [known issues](https://learn.microsoft.com/en-us/azure/azure-vmware/azure-vmware-solution-known-issues).

> **Important — Dual Severity Forms:** VMware systems may log both the abbreviated form (`emerg`, `crit`, `err`) and the full-word form (`emergency`, `critical`, `error`). The [AVSSyslog schema](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/avssyslog) lists the acceptable values as: `debug, info, notice, warn, err, crit, alert, emerg`. In practice, both abbreviated and full-word forms have been observed. All queries in this solution use `Severity in ("emerg", "emergency")` etc. to match both forms and prevent missed events.

**Why only Severity 0–3?**
- Severity 0–2 events (`emerg`, `alert`, `crit`) are rare and almost always indicate a real problem — they should trigger immediate alerts.
- Severity 3 (`err`/`error`) events are more common and can include routine errors. The Sev2-Error alert is **disabled by default** with a configurable threshold (default: 5 per host per 15 min) to avoid alert fatigue. Enable it only after reviewing your baseline.
- Severity 4–7 (`warning` through `debug`) generate high volume and are best monitored visually in the workbook rather than via alerts.

In addition to severity-based alerts, this solution provides **10 event-specific alerts** (Part 2) that detect specific VMware events in the `Message` field — such as host failures, VM disconnections, DNS failures, and firewall blocks — regardless of what severity level they were logged at.

### Part 1 — Severity-Based Alerts

These alerts fire based on the syslog `Severity` field value. VMware may log abbreviated (`emerg`, `crit`, `err`) or full-word (`emergency`, `critical`, `error`) forms — queries match both.

#### Sev0-Emergency

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Severity in ("emerg", "emergency")
| where not(AppName == "NSX" and (Message has "Accepts incoming connection from TN" or Message has "Finishes fullsync with TN"))
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

> **Note:** Excludes two NSX transport-node connection success-path messages that NSX-T mislabels as `emerg`. See [Known Noisy Events](#-known-noisy-events--exclusion-filters) below.

#### Sev0-Alert

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Severity == "alert"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Sev1-Critical

| Property | Value |
|---|---|
| **Azure Severity** | 1 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Severity in ("crit", "critical")
| where not(AppName == "vsand" and Message has "CalculateHostStats")
| where not(AppName in ("clomd", "clomd-whatif"))
| where not(AppName == "etcd" and Message has "failed to purge snap file")
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

> **Note:** The deployed alert rule automatically excludes ~99% of platform noise from Microsoft-managed vSAN/control-plane components (`vsand`, `clomd`, `clomd-whatif`, `etcd`). See [Known Noisy Events](#-known-noisy-events--exclusion-filters) below.

#### Sev2-Error (optional — can be noisy)

| Property | Value |
|---|---|
| **Azure Severity** | 2 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 (query pre-filters at > 5 per HostName + AppName — configurable) |
| **Default** | ❌ Disabled |

```kql
AVSSyslog
| where Severity in ("err", "error")
| summarize ErrorCount = count() by HostName, AppName, bin(TimeGenerated, 15m)
| where ErrorCount > 5
```

> **Tip:** Adjust the `ErrorCount > 5` threshold to match your environment baseline. This alert is disabled by default to avoid noise.

---

### Part 2 — Event-Specific Alerts

#### Host-ConnectionLost

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "lost connection to the host"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Host-Shutdown

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "hostshutdownevent"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### VM-Disconnected

| Property | Value |
|---|---|
| **Azure Severity** | 1 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "vmdisconnectedevent"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### VM-RemovedFromInventory

| Property | Value |
|---|---|
| **Azure Severity** | 1 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "vmremovedevent"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### VM-GuestReboot

| Property | Value |
|---|---|
| **Azure Severity** | 2 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "VmGuestRebootEvent"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### DNS-Failures

| Property | Value |
|---|---|
| **Azure Severity** | 1 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 (query pre-filters at > 10 per host — configurable) |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where AppName == "dnsmasq"
| where Message has "Failed DNS Query"
| summarize FailureCount = count() by HostName, bin(TimeGenerated, 15m)
| where FailureCount > 10
```

> Adjust `FailureCount > 10` to your baseline.

#### NSX-DFW-BlockedSpike

| Property | Value |
|---|---|
| **Azure Severity** | 2 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 (query pre-filters at > 50 per host — configurable) |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where AppName == "FIREWALL" or ProcId == "FIREWALL"
| where Message has_any ("DROP", "REJECT", "denied")
| summarize BlockedCount = count() by HostName, bin(TimeGenerated, 15m)
| where BlockedCount > 50
```

> Adjust `BlockedCount > 50` to your baseline.

#### Host-MaintenanceMode

| Property | Value |
|---|---|
| **Azure Severity** | 2 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has_any ("The host has entered maintenance mode", "The host has exited maintenance mode")
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Security-RoleChange

| Property | Value |
|---|---|
| **Azure Severity** | 1 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 15 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Message has "RoleAddedEvent"
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Syslog-IngestionHeartbeat

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Frequency** | Every 5 minutes |
| **Lookback Window** | 30 minutes |
| **Aggregation** | Count |
| **Operator / Threshold** | Greater than 0 (alerts when query returns a row indicating no recent ingest) |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| summarize LastIngest = max(TimeGenerated)
| where isnull(LastIngest) or LastIngest < ago(30m)
```

> **How this works:** The query returns a row only when the last ingest time is missing or older than 30 minutes. The alert fires when row count is greater than 0 (i.e., the unhealthy condition is true). This is the standard "absence of data" pattern for log-based alerts. The previous `summarize count() | == 0` form does **not** work because `summarize count()` always returns exactly one row, so the count condition would never be met.

---

## 🔔 Action Group Routing

Alerts are grouped into three severity tiers. Assign a different action group per tier, or use the same group for all.

| Tier | Azure Severity | Alerts Routed |
|---|:---:|---|
| **Sev 0** — Critical | 0 | Emergency, Alert, Host Connection Lost, Host Shutdown, Ingestion Heartbeat |
| **Sev 1** — High | 1 | Critical, VM Disconnected, VM Removed, DNS Failures, Role Changes |
| **Sev 2** — Moderate | 2 | Error, DFW Spike, Host Maintenance Mode, VM Guest Reboot |

---

## �️ Threshold Tuning Guide

Only **3 of the 14 alerts** use thresholds — they are **volume-based** because individual events are normal but a *spike* indicates a problem. The other 11 alerts fire on first occurrence (severity-based or discrete events like host shutdowns) and don't need a threshold.

### Why only these 3?

| Alert | Why it has a threshold |
|---|---|
| **Sev2-Error** | Single errors are common (transient hostd retries, brief network blips). Sustained errors from the same `HostName + AppName` combination indicate a real problem. |
| **DNS Failures** | A single failed DNS query is normal (typo, scanner, expired cache). Many failures from one host = real DNS server issue. |
| **DFW Blocked Spike** | The firewall blocking traffic *is its job*. A sudden surge above baseline = potential attack, scanning, or misconfigured app. |

All other alerts use threshold **= 0** (any occurrence fires) because the event itself is the signal: a host going down, a VM being removed, a permission change — these warrant immediate investigation.

### Recommended baselines

| Threshold | Default | Lower it (more sensitive) | Raise it (less noisy) |
|---|---:|---|---|
| **Error events / 15 min** | `5` | `2–3` for very stable environments where any error matters | `10–20` if you have a chatty AppName generating frequent transient errors |
| **DNS failures / 15 min** | `10` | `5` for early warning of DNS server issues | `25–50` if your VMs frequently query non-existent records (security scanners, misconfigured apps, internal CDN lookups) |
| **DFW blocks / 15 min** | `50` | `20` for security-sensitive workloads where any spike matters | `100–200` for high-traffic clusters or environments with deny-by-default policies |

### Tuning workflow

1. **Deploy with defaults.** Let the alerts run for 1–2 weeks.
2. **Check Azure Monitor → Alerts** for false-positive rate. Use the workbook's **Top Repeated Error Messages** panel to see which `AppName` is dominant.
3. **Adjust per environment**:
   - If a single AppName is generating noise → raise the Error threshold (or add an exclusion filter for that AppName, see [Known Noisy Events](#-known-noisy-events--exclusion-filters))
   - If alerts are too quiet during real incidents → lower the threshold
4. **Re-run the deployment** with the new threshold value, or edit the alert rule directly in **Monitor → Alerts → Alert rules → Edit**.

> **Tip:** For ad-hoc spike detection (e.g., during incident response), raise thresholds temporarily rather than disabling alerts — that way you keep the signal during the *next* incident.

### What about adding more thresholds?

The other 11 alerts intentionally don't have thresholds. Adding one to (e.g.) Host-Shutdown would be wrong — you want to know about every host shutdown, not "more than 3 in 15 minutes." The right tool for suppressing alerts during planned events (patch nights, upgrades) is **Azure Monitor [alert processing rules](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-action-rules)** with a maintenance window, not a threshold change.

---

## �🏷️ Alert Naming Convention

All alert rule names follow: `{Prefix}-{Category}-{Name}`

With the default prefix `AVS`:

| Category | Examples |
|---|---|
| Severity-based | `AVS-Syslog-Sev0-Emergency`, `AVS-Syslog-Sev1-Critical` |
| Event-specific | `AVS-Event-Host-ConnectionLost`, `AVS-Event-VM-Disconnected` |
| Network | `AVS-Event-DNS-Failures`, `AVS-Event-NSX-DFW-BlockedSpike` |
| Audit | `AVS-Event-Security-RoleChange`, `AVS-Event-Host-MaintenanceMode` |
| Pipeline | `AVS-Meta-Syslog-IngestionHeartbeat` |

---

## 📁 Repository Files

| File | Description |
|---|---|
| `avs-syslog-workbook-deploy-template.json` | ARM template to deploy the workbook as an Azure resource. |
| `avs-syslog-workbook-gallery.json` | Raw workbook JSON for manual import via the Advanced Editor. |
| `avs-syslog-alerts-deploy-template.json` | ARM template with 14 Scheduled Query Rules and per-alert boolean toggles. |
| `createUiDefinition.json` | Custom portal UI for the alert deployment wizard (resource pickers, sliders). |
| `avs-service-health-alert-template.json` | ARM template for Azure Service Health alerts filtered to Azure VMware Solution. |
| `createUiDefinition-service-health.json` | Custom portal UI for the Service Health deployment (action group picker). |

---

## ⚙️ Deployment Parameters — Alert Template

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workspaceResourceId` | string | *(required)* | Log Analytics workspace receiving AVSSyslog. |
| `alertNamePrefix` | string | `AVS` | Prefix for all alert rule names. |
| `actionGroupIdSev0` | string | `""` | Action group for Severity 0 alerts. |
| `actionGroupIdSev1` | string | `""` | Action group for Severity 1 alerts. |
| `actionGroupIdSev2` | string | `""` | Action group for Severity 2 alerts. |
| `errThresholdPer15m` | int | `5` | Error threshold per HostName + AppName per 15 min. |
| `dnsFailureThresholdPer15m` | int | `10` | DNS failure threshold per host per 15 min. |
| `dfwSpikeThresholdPer15m` | int | `50` | DFW blocked traffic threshold per host per 15 min. |
| `deploySev0Emergency` | bool | `true` | Deploy the Emergency alert. |
| `deploySev0Alert` | bool | `true` | Deploy the Alert-severity alert. |
| `deploySev1Critical` | bool | `true` | Deploy the Critical alert. |
| `deploySev2Error` | bool | `false` | Deploy the Error alert (noisy — baseline first). |
| `deployHostConnectionLost` | bool | `true` | Host Connection Lost alert. |
| `deployHostShutdown` | bool | `true` | Host Shutdown alert. |
| `deployVmDisconnected` | bool | `true` | VM Disconnected alert. |
| `deployVmRemovedFromInventory` | bool | `true` | VM Removed from Inventory alert. |
| `deployVmGuestReboot` | bool | `true` | VM Guest Reboot alert. |
| `deployDnsFailures` | bool | `true` | DNS Failures alert. |
| `deployDfwSpike` | bool | `true` | DFW Blocked Spike alert. |
| `deployHostMaintenanceMode` | bool | `true` | Host Maintenance Mode alert. |
| `deployRolePermissionChanges` | bool | `true` | Role/Permission Changes alert. |
| `deploySyslogIngestionHeartbeat` | bool | `true` | Syslog Ingestion Heartbeat alert. |

---

## 🔇 Known Noisy Events & Exclusion Filters

VMware platform components can generate large volumes of severity `critical` and `error` events that are **infrastructure-level diagnostic messages managed by Microsoft** — not customer-actionable problems. The workbook displays all events for full visibility with grouping panels, but the **alert rules exclude known noisy patterns** to prevent alert fatigue.

### Excluded sources (Sev 1 Critical alert)

Analysis of real AVS environments shows ~99% of "critical" syslog events come from four Microsoft-managed vSAN/control-plane components that customers cannot patch or reconfigure:

| AppName | Pattern | What it is |
|---|---|---|
| `vsand` | `calculator::CalculateHostStats ... outdated data` | vSAN stats calculator — high-res data was stale, calc skipped. No data loss. ~895 events / 1,000 sample. |
| `clomd` | `CLOMDecomMonitor` / `CLOMDecomCMMDSResponseCb` / `CLOM_CrawlItem` | vSAN Cluster-Level Object Manager looking up already-deleted decommission objects. Self-resolving. ~89 events / 1,000 sample. |
| `clomd-whatif` | `CLOMAddNodesToJSONString ... decommission complete` | vSAN planning simulation — informational, daemon logs it at "critical". ~13 events / 1,000 sample. |
| `etcd` | `failed to purge snap file ... device or resource busy` | etcd housekeeping retry — transient lock on snap file purge, self-resolves. ~3 events / 1,000 sample. |

**Why it's safe to exclude:**
- All four are part of the **Microsoft-managed AVS infrastructure** ([shared responsibility](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/azure-vmware/manage)) — customers cannot patch, restart, or reconfigure them.
- The "critical" severity reflects the daemon's internal log level, not actionable customer impact.
- Real customer-actionable critical events come from `hostd`, `vmkernel`, `vpxd`, NSX components — these are **not** excluded.
- If the pattern changes (volume spikes, new sources appear), the workbook's **Top Repeated Critical Messages** and **Critical Events by Source** panels will make it visible.

**Exclusion filter used in the Sev1-Critical alert rule:**
```kql
| where not(AppName == "vsand" and Message has "CalculateHostStats")
| where not(AppName in ("clomd", "clomd-whatif"))
| where not(AppName == "etcd" and Message has "failed to purge snap file")
```

**If you create alerts manually**, add these filters after the severity filter. If you use the **Deploy to Azure** button, they're already included.

**Workbook visibility:** A dedicated **🟠 Customer-Actionable Critical Events** panel in the workbook applies the same exclusions, giving operators a clear "what to look at" view alongside the full unfiltered critical event grid.

### Excluded patterns (Sev 0 Emergency alert)

NSX-T Manager is known to log certain control-plane lifecycle events with the syslog `local6.emerg` facility/severity even though they are informational. The Sev 0 Emergency alert excludes only **two specific success-path NSX patterns**:

| AppName | Pattern | What it is |
|---|---|---|
| `NSX` | `Accepts incoming connection from TN <UUID>` | NSX Manager accepting an ESXi transport-node (TN) connection. Normal lifecycle event after host reboot, NSX upgrade, or reconnect. |
| `NSX` | `Finishes fullsync with TN <UUID>, mark as connected` | NSX Manager completed initial state sync with a transport node. This is the **success path** — the TN is now healthy. |

**Why it's safe to exclude:**
- The NSX Manager appliances (`TNTxxx-NSX-APPxx` hostnames) are **Microsoft-managed** under the AVS shared responsibility model — customers cannot tune their syslog severity.
- The message text describes routine connection acceptance and *successful* fullsync completion — by definition, the opposite of "system unusable."
- **Narrow exclusion:** only these two exact success-path messages are filtered. **Any other NSX `emerg` event still alerts**, so real NSX control-plane failures (auth errors, cluster-split, certificate issues, etc.) will still page you.

**Watch out for:** if you see the same TN UUID reconnecting **many times in a short window** (e.g., dozens per hour), that's a potential reconnect-storm worth investigating. The workbook's **Top Repeated Emergency Messages** panel makes this visible — it will surface a high count for the same UUID even though individual events don't alert.

**Exclusion filter used in the Sev0-Emergency alert rule:**
```kql
| where not(AppName == "NSX" and (Message has "Accepts incoming connection from TN" or Message has "Finishes fullsync with TN"))
```

**Workbook visibility:** A dedicated **🔴 Customer-Actionable Emergency Events** panel applies the same exclusion alongside the unfiltered emergency event grid.

### Adding Custom Exclusions

If your environment has other noisy patterns, you can add exclusions after deployment by editing the alert rule in **Monitor → Alerts → Alert rules → Edit**. Add additional `where not(...)` clauses:

```kql
AVSSyslog
| where Severity in ("crit", "critical")
| where not(AppName == "vsand" and Message has "CalculateHostStats")
| where not(AppName in ("clomd", "clomd-whatif"))
| where not(AppName == "etcd" and Message has "failed to purge snap file")
| where not(Message has "your-other-noisy-pattern-here")
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

---

## 🔍 Exploration Queries

Run these in your Log Analytics workspace to validate data before enabling alerts.

**Check if AVSSyslog table has data:**
```kql
AVSSyslog
| take 10
```

**Severity distribution (last 24h):**
```kql
AVSSyslog
| where TimeGenerated > ago(24h)
| summarize Count = count() by Severity
| order by Count desc
```

**High-impact events by host:**
```kql
AVSSyslog
| where TimeGenerated > ago(24h)
| where Severity in ("emerg", "emergency", "alert", "crit", "critical", "err", "error")
| summarize Count = count() by HostName, Severity
| order by Count desc
```

**Top event sources:**
```kql
AVSSyslog
| where TimeGenerated > ago(24h)
| summarize Count = count() by AppName
| top 15 by Count desc
```

---

## 📖 References

- [Microsoft — Queries for the AVSSyslog table](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/queries/avssyslog)
- [AVSSyslog table schema](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/avssyslog)
- [Azure VMware Solution — Configure syslogs](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs)
- [RFC 5424 — Syslog Severity Levels](https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1)
- [Azure Monitor — Scheduled Query Rules API](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
