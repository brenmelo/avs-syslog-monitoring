# AVS Syslog Alerts

Complete Azure Monitor alert rules for Azure VMware Solution (AVS) syslog monitoring. Includes severity-based and event-specific alerts with one-click deployment from Azure workbooks.

## Contents

- **avs-syslog-alerts-deploy-template.json** — ARM deployment template for scheduled query rules with selectable alert checkboxes
- **avs-syslog-workbook-gallery.json** — Azure Monitor Workbook with integrated Deploy button

## Quick Start

1. Import the workbook into Azure Monitor
2. Click the **Deploy AVS Syslog Alerts** button
3. Choose which alerts to deploy (defaults: Core + Recommended)
4. Provide your Log Analytics workspace and action group IDs
5. Deploy

## Deployment Parameters

### Required
- `workspaceResourceId` — Log Analytics workspace resource ID containing AVSSyslog table
- `actionGroupIdsSev0` — Action group IDs for Severity 0 alerts (emergency, alert)
- `actionGroupIdsSev1` — Action group IDs for Severity 1 (critical) 
- `actionGroupIdsSev2` — Action group IDs for Severity 2 (error) and event-specific alerts

### Optional
- `alertNamePrefix` — Prefix for all alert names (default: `AVS`)
- `errThresholdPer15m` — Threshold for Severity 3 err/error (default: 5)
- `dnsFailureThresholdPer15m` — Threshold for DNS failures (default: 10)
- `dfwSpikeThresholdPer15m` — Threshold for DFW blocked traffic (default: 50)

### Alert Selection (All Booleans)
Choose which alerts to deploy:
- `deploySev0Emergency`, `deploySev0Alert`, `deploySev1Critical`, `deploySev2Error` — Severity-based alerts
- `deployHostConnectionLost`, `deployHostShutdown`, `deployVmDisconnected`, `deployVmRemovedFromInventory`, `deployVmGuestReboot` — Host/VM events
- `deployDnsFailures`, `deployDfwSpike` — Network events
- `deployHostMaintenanceMode`, `deployRolePermissionChanges` — Audit events
- `deploySyslogIngestionHeartbeat` — Pipeline health

## Alert Details

See the corresponding email documentation (`email-reply-avs-syslog-alerts-v3.html`) for detailed KQL queries, thresholds, action group routing recommendations, and naming conventions.

## References

- [Microsoft — Queries for the AVSSyslog table](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/queries/avssyslog)
- [RFC 5424 — Syslog Severity Levels](https://datatracker.ietf.org/doc/html/rfc5424#section-6.2.1)
- [Azure VMware Solution — Configure syslogs](https://learn.microsoft.com/en-us/azure/azure-vmware/configure-vmware-syslogs)
