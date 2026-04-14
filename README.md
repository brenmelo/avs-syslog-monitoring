# AVS Syslog Monitoring — Workbook & Alerts

Pre-built Azure Monitor **Workbook** and **14 alert rules** for monitoring [Azure VMware Solution (AVS)](https://learn.microsoft.com/en-us/azure/azure-vmware/) syslog events. Everything runs against the `AVSSyslog` Log Analytics table.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **AVS private cloud** | With a [Diagnostic Setting](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs) that sends the **Syslog** category to a Log Analytics workspace. |
| **Log Analytics workspace** | The workspace that receives `AVSSyslog` data. |
| **Action Group(s)** | At least one [Action Group](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups) for alert notifications. Required only for alert deployment. |

### Configure AVS Syslog Forwarding

Before deploying, your AVS private cloud must be sending syslog data to a Log Analytics workspace:

1. In the Azure portal, navigate to your **Azure VMware Solution** private cloud.
2. Go to **Diagnostic settings** → **+ Add diagnostic setting**.
3. Check the **Syslog** category.
4. Under **Destination details**, select **Send to Log Analytics workspace** and choose your workspace.
5. Click **Save**.

Verify data is flowing after a few minutes:

```kql
AVSSyslog
| take 10
```

> For full details, see [Configure VMware syslogs for Azure VMware Solution](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs).

---

## 1. Deploy the Workbook

The workbook gives you real-time dashboards for severity distribution, event-specific monitoring, host health, and pipeline status — start here.

### Option A — One-click Deploy

[![Deploy Workbook to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-monitoring%2Fmain%2Favs-syslog-workbook-deploy-template.json)

1. Click the button above.
2. Select your **Subscription** and **Resource Group**.
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

## 2. Deploy the Alert Rules

### Option A — Deploy from the Workbook (recommended)

If you deployed the workbook in Step 1, open it and click the **Deploy to Azure** button at the top of the workbook:

![Deploy from Workbook](images/workbook-deploy-button.png)

1. Open your deployed workbook: **Monitor → Workbooks → AVS Syslog Monitoring**.
2. Click the **Deploy to Azure** button shown above.
3. A guided wizard walks you through:
   - **Basics** — Subscription, resource group, Log Analytics workspace.
   - **Action Groups** — Pick existing action groups for Severity 0, 1, and 2.
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

## Alert Rules Reference

### Part 1 — Severity-Based Alerts

These alerts fire based on the syslog `Severity` field value. VMware may log abbreviated (`emerg`, `crit`, `err`) or full-word (`emergency`, `critical`, `error`) forms — queries match both.

#### Sev0-Emergency

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Threshold** | > 0 (any occurrence) |
| **Window** | 15 min |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Severity in ("emerg", "emergency")
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Sev0-Alert

| Property | Value |
|---|---|
| **Azure Severity** | 0 |
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where Severity in ("crit", "critical")
| project TimeGenerated, HostName, AppName, Facility, Severity, Message
```

#### Sev2-Error (optional — can be noisy)

| Property | Value |
|---|---|
| **Azure Severity** | 2 |
| **Threshold** | > 5 per HostName + AppName (configurable) |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 10 per host (configurable) |
| **Window** | 15 min |
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
| **Threshold** | > 50 per host (configurable) |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | > 0 |
| **Window** | 15 min |
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
| **Threshold** | == 0 (fires when **no** data arrives) |
| **Window** | 30 min |
| **Default** | ✅ Enabled |

```kql
AVSSyslog
| where TimeGenerated > ago(30m)
| summarize Count = count()
```

> This alert fires when the count equals zero — meaning no syslog data has been ingested in 30 minutes. Set the condition to `Equal` → `0`.

---

## Action Group Routing

Alerts are grouped into three severity tiers. Assign a different action group per tier, or use the same group for all.

| Tier | Azure Severity | Alerts Routed |
|---|:---:|---|
| **Sev 0** — Critical | 0 | Emergency, Alert, Host Connection Lost, Host Shutdown, Ingestion Heartbeat |
| **Sev 1** — High | 1 | Critical, VM Disconnected, VM Removed, DNS Failures, Role Changes |
| **Sev 2** — Moderate | 2 | Error, DFW Spike, Host Maintenance Mode, VM Guest Reboot |

---

## Alert Naming Convention

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

## Repository Files

| File | Description |
|---|---|
| `avs-syslog-workbook-deploy-template.json` | ARM template to deploy the workbook as an Azure resource. |
| `avs-syslog-workbook-gallery.json` | Raw workbook JSON for manual import via the Advanced Editor. |
| `avs-syslog-alerts-deploy-template.json` | ARM template with 14 Scheduled Query Rules and per-alert boolean toggles. |
| `createUiDefinition.json` | Custom portal UI for the alert deployment wizard (resource pickers, sliders). |

---

## Deployment Parameters — Alert Template

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

## Syslog Severity Reference (RFC 5424)

| Code | Keyword | Description |
|:---:|---|---|
| 0 | `emerg` / `emergency` | System is unusable |
| 1 | `alert` | Action must be taken immediately |
| 2 | `crit` / `critical` | Critical conditions |
| 3 | `err` / `error` | Error conditions |
| 4 | `warning` | Warning conditions |
| 5 | `notice` | Normal but significant condition |
| 6 | `info` | Informational messages |
| 7 | `debug` | Debug-level messages |

> **Note:** VMware systems may log both abbreviated and full-word severity forms. All queries in this solution match both to prevent missed events.

---

## Exploration Queries

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

## References

- [Microsoft — Queries for the AVSSyslog table](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/queries/avssyslog)
- [AVSSyslog table schema](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/avssyslog)
- [Azure VMware Solution — Configure syslogs](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs)
- [RFC 5424 — Syslog Severity Levels](https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1)
- [Azure Monitor — Scheduled Query Rules API](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
