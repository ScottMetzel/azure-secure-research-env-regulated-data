@description('Azure region for the Log Analytics workspace.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Number of days to retain log data.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

// ── Resources ────────────────────────────────────────────────────────────────

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${environmentName}-law'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The Log Analytics workspace customer/GUID ID (used for direct Log Analytics API queries and some monitoring tool configurations).')
output workspaceId string = logAnalyticsWorkspace.properties.customerId

@description('The name of the Log Analytics workspace.')
output workspaceName string = logAnalyticsWorkspace.name

@description('The ARM resource ID of the Log Analytics workspace (used for diagnostic settings and resource references).')
output workspaceResourceId string = logAnalyticsWorkspace.id
