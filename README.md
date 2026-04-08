# AVS Syslog Alerts

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-alerts%2Fmain%2Favs-syslog-alerts-deploy-template.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrenmelo%2Favs-syslog-alerts%2Fmain%2FcreateUiDefinition.json)

Pre-built Azure Monitor alert rules and an Azure Monitor Workbook for monitoring [Azure VMware Solution (AVS)](https://learn.microsoft.com/en-us/azure/azure-vmware/) syslog events. Covers **14 alert rules** across severity-based and event-specific scenarios, all deployed as Scheduled Query Rules against the `AVSSyslog` Log Analytics table.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **AVS private cloud** | With a [Diagnostic Setting](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs) that sends the **Syslog** category to a Log Analytics workspace. |
| **Log Analytics workspace** | The workspace that receives `AVSSyslog` data. |
| **Action Group(s)** | At least one [Action Group](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups) (email, SMS, webhook, etc.) for alert notifications. You can use one group for all severities or separate groups per severity level. |

### Configure AVS Syslog Forwarding

Before deploying alerts, your AVS private cloud must be sending syslog data to a Log Analytics workspace. If you haven't done this yet:

1. In the Azure portal, navigate to your **Azure VMware Solution** private cloud.
2. Go to **Diagnostic settings** → **+ Add diagnostic setting**.
3. Check the **Syslog** category.
4. Under **Destination details**, select **Send to Log Analytics workspace** and choose your workspace.
5. Click **Save**.

After a few minutes, the `AVSSyslog` table will begin receiving data. You can verify with:

```kql
AVSSyslog
| take 10
```

> For full configuration details, see [Configure VMware syslogs for Azure VMware Solution](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs).

---

## Quick Start

### Option A — One-click Deploy (recommended)

1. Click the **Deploy to Azure** button above.
2. A guided wizard walks you through four steps:
   - **Basics** — Select your subscription, resource group, and Log Analytics workspace from a dropdown picker.
   - **Action Groups** — Pick existing action groups for Severity 0, 1, and 2 alerts.
   - **Select Alerts** — Check or uncheck each of the 14 alert rules.
   - **Thresholds** — Use sliders to set thresholds for volume-based alerts (Error, DNS, DFW).
3. Click **Review + create** → **Create**.

### Option B — Import the Workbook first

1. In the Azure portal, go to **Monitor → Workbooks → + New**.
2. Open the **Advanced Editor** (`</>` icon).
3. Paste the contents of [`avs-syslog-workbook-gallery.json`](avs-syslog-workbook-gallery.json) and click **Apply**.
4. Save the workbook to your resource group.
5. Use the **Deploy AVS Syslog Alerts** button inside the workbook to launch the same deployment wizard.

### Option C — Azure CLI

```bash
az deployment group create \
  --resource-group <your-rg> \
  --template-file avs-syslog-alerts-deploy-template.json \
  --parameters workspaceResourceId="<workspace-resource-id>" \
               actionGroupIdSev0="<action-group-resource-id>" \
               actionGroupIdSev1="<action-group-resource-id>" \
               actionGroupIdSev2="<action-group-resource-id>"
```

---

## What's Included

### Repository Files

| File | Description |
|---|---|
| `avs-syslog-alerts-deploy-template.json` | ARM template with 14 Scheduled Query Rules and per-alert boolean toggles. |
| `createUiDefinition.json` | Custom portal UI definition that provides resource pickers and a guided wizard. |
| `avs-syslog-workbook-gallery.json` | Azure Monitor Workbook with dashboards for all severity levels, event types, host health, and pipeline status. |

### Workbook Sections

The workbook provides real-time visibility into your AVS syslog data:

- **Overview** — Severity distribution tiles and pie chart, top event sources by AppName.
- **Part 1 — Severity-Based Monitoring** — Time series and detail grids for Emergency, Alert, Critical, and Error events.
- **Part 2 — Event-Specific Monitoring** — Summary tiles and detail grids for host failures, VM changes, DNS, DFW, maintenance, and role changes.
- **Host Health Overview** — Per-host heatmap and trend of high-impact events.
- **Data Pipeline Health** — Syslog ingestion heartbeat tile and volume chart.

---

## Alert Rules Reference

### Part 1 — Severity-Based Alerts

These alerts fire based on the syslog `Severity` field value. VMware systems may log both abbreviated and full-word severity forms, so queries match both (e.g., `emerg` and `emergency`).

| Alert Name | Severity | KQL Match | Threshold | Window | Default |
|---|:---:|---|:---:|:---:|:---:|
| **Sev0-Emergency** | 0 | `Severity in ("emerg", "emergency")` | > 0 | 15 min | ✅ On |
| **Sev0-Alert** | 0 | `Severity == "alert"` | > 0 | 15 min | ✅ On |
| **Sev1-Critical** | 1 | `Severity in ("crit", "critical")` | > 0 | 15 min | ✅ On |
| **Sev2-Error** | 2 | `Severity in ("err", "error")` | > configurable* | 15 min | ❌ Off |

> \* **Sev2-Error** is disabled by default because `err`/`error` events can be high-volume. Enable it only after establishing a baseline. The threshold is configurable (default: **5** per HostName + AppName per 15-minute window).

### Part 2 — Event-Specific Alerts

These alerts fire on specific VMware events detected in the `Message` field, regardless of severity level.

| Alert Name | Severity | KQL Match | Threshold | Window | Default |
|---|:---:|---|:---:|:---:|:---:|
| **Host-ConnectionLost** | 0 | `Message has "lost connection to the host"` | > 0 | 15 min | ✅ On |
| **Host-Shutdown** | 0 | `Message has "hostshutdownevent"` | > 0 | 15 min | ✅ On |
| **VM-Disconnected** | 1 | `Message has "vmdisconnectedevent"` | > 0 | 15 min | ✅ On |
| **VM-RemovedFromInventory** | 1 | `Message has "vmremovedevent"` | > 0 | 15 min | ✅ On |
| **VM-GuestReboot** | 2 | `Message has "VmGuestRebootEvent"` | > 0 | 15 min | ✅ On |
| **DNS-Failures** | 1 | `AppName == "dnsmasq"` and `Message has "Failed DNS Query"` | > configurable* | 15 min | ✅ On |
| **NSX-DFW-BlockedSpike** | 2 | `AppName == "FIREWALL"` or `ProcId == "FIREWALL"` with `DROP/REJECT/denied` | > configurable* | 15 min | ✅ On |
| **Host-MaintenanceMode** | 2 | `Message has_any ("entered maintenance mode", "exited maintenance mode")` | > 0 | 15 min | ✅ On |
| **Security-RoleChange** | 1 | `Message has "RoleAddedEvent"` | > 0 | 15 min | ✅ On |
| **Syslog-IngestionHeartbeat** | 0 | `AVSSyslog \| where TimeGenerated > ago(30m) \| summarize Count = count()` | == 0 | 30 min | ✅ On |

> **Configurable thresholds:**
> - DNS Failures — default **10** per host per 15 min
> - DFW Blocked Spike — default **50** per host per 15 min

---

## Action Group Routing

Alerts are grouped into three severity tiers. You can assign a different action group to each tier, or use the same group for all.

| Tier | Azure Severity | Alerts Routed |
|---|:---:|---|
| **Sev 0** — Critical | 0 | Emergency, Alert, Host Connection Lost, Host Shutdown, Ingestion Heartbeat |
| **Sev 1** — High | 1 | Critical, VM Disconnected, VM Removed, DNS Failures, Role Changes |
| **Sev 2** — Moderate | 2 | Error, DFW Spike, Host Maintenance Mode, VM Guest Reboot |

---

## Alert Naming Convention

All alert rule names follow the pattern:

```
{Prefix}-{Category}-{Name}
```

With the default prefix `AVS`, deployed rule names look like:

| Category | Examples |
|---|---|
| Severity-based | `AVS-Syslog-Sev0-Emergency`, `AVS-Syslog-Sev1-Critical` |
| Event-specific | `AVS-Event-Host-ConnectionLost`, `AVS-Event-VM-Disconnected` |
| Network | `AVS-Event-DNS-Failures`, `AVS-Event-NSX-DFW-BlockedSpike` |
| Audit | `AVS-Event-Security-RoleChange`, `AVS-Event-Host-MaintenanceMode` |
| Pipeline | `AVS-Meta-Syslog-IngestionHeartbeat` |

---

## Deployment Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workspaceResourceId` | string | *(required)* | Resource ID of the Log Analytics workspace receiving AVSSyslog. |
| `alertNamePrefix` | string | `AVS` | Prefix for all alert rule names. |
| `actionGroupIdSev0` | string | `""` | Action group for Severity 0 alerts. |
| `actionGroupIdSev1` | string | `""` | Action group for Severity 1 alerts. |
| `actionGroupIdSev2` | string | `""` | Action group for Severity 2 alerts. |
| `errThresholdPer15m` | int | `5` | Error event threshold per HostName + AppName per 15 min. |
| `dnsFailureThresholdPer15m` | int | `10` | DNS failure threshold per host per 15 min. |
| `dfwSpikeThresholdPer15m` | int | `50` | DFW blocked traffic threshold per host per 15 min. |
| `deploySev0Emergency` | bool | `true` | Deploy the Emergency alert rule. |
| `deploySev0Alert` | bool | `true` | Deploy the Alert-severity alert rule. |
| `deploySev1Critical` | bool | `true` | Deploy the Critical alert rule. |
| `deploySev2Error` | bool | `false` | Deploy the Error alert rule (noisy — establish baseline first). |
| `deployHostConnectionLost` | bool | `true` | Deploy the Host Connection Lost alert. |
| `deployHostShutdown` | bool | `true` | Deploy the Host Shutdown alert. |
| `deployVmDisconnected` | bool | `true` | Deploy the VM Disconnected alert. |
| `deployVmRemovedFromInventory` | bool | `true` | Deploy the VM Removed from Inventory alert. |
| `deployVmGuestReboot` | bool | `true` | Deploy the VM Guest Reboot alert. |
| `deployDnsFailures` | bool | `true` | Deploy the DNS Failures alert. |
| `deployDfwSpike` | bool | `true` | Deploy the DFW Blocked Spike alert. |
| `deployHostMaintenanceMode` | bool | `true` | Deploy the Host Maintenance Mode alert. |
| `deployRolePermissionChanges` | bool | `true` | Deploy the Role/Permission Changes alert. |
| `deploySyslogIngestionHeartbeat` | bool | `true` | Deploy the Syslog Ingestion Heartbeat alert. |

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

> **Note:** VMware systems may log both abbreviated (`emerg`, `crit`, `err`) and full-word (`emergency`, `critical`, `error`) severity forms. All queries in this solution match both forms to prevent missed events.

---

## Exploration Queries

Run these in your Log Analytics workspace to validate syslog data before enabling alerts.

**Check if AVSSyslog table has data:**
```kql
AVSSyslog
| take 10
```

**Severity distribution over the last 24 hours:**
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
