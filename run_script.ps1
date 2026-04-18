Set-Location C:\Users\brennermelo\avs-syslog-alerts
$gallery = Get-Content avs-syslog-workbook-gallery.json -Raw
$indented = ($gallery -split "`n" | ForEach-Object { '    ' + $_ }) -join "`n"
$indented = $indented.TrimEnd()
$header = '{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "workbookDisplayName": {
      "type": "string",
      "defaultValue": "AVS Syslog Monitoring",
      "metadata": {
        "description": "The display name of the workbook."
      }
    }
  },
  "variables": {
    "workbookId": "[guid(parameters(''workbookDisplayName''), resourceGroup().id)]",
    "workbookContent":
'
$footer = '
  },
  "resources": [
    {
      "type": "Microsoft.Insights/workbooks",
      "apiVersion": "2023-06-01",
      "name": "[variables(''workbookId'')]",
      "location": "[resourceGroup().location]",
      "kind": "shared",
      "properties": {
        "displayName": "[parameters(''workbookDisplayName'')]",
        "serializedData": "[string(variables(''workbookContent''))]",
        "version": "Notebook/1.0",
        "sourceId": "Azure Monitor",
        "category": "workbook"
      }
    }
  ]
}
'
$combined = $header + $indented + $footer
Set-Content -Path avs-syslog-workbook-deploy-template.json -Value $combined -NoNewline -Encoding UTF8
"Size: $((Get-Item avs-syslog-workbook-deploy-template.json).Length) bytes"
try { Get-Content avs-syslog-workbook-deploy-template.json -Raw | ConvertFrom-Json | Out-Null; "JSON valid" } catch { "INVALID: $_" }
