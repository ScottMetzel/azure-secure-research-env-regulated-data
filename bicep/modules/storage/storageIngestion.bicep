@description('Azure region for the ingestion storage account.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

// ── Storage Account ───────────────────────────────────────────────────────────

// Storage account names must be globally unique, 3-24 lowercase alphanumeric characters.
var storageAccountName = toLower(take('${replace(environmentName, '-', '')}ingest${uniqueString(resourceGroup().id)}', 24))

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      // Ingestion storage is intentionally accessible from outside to receive raw data uploads.
      defaultAction: 'Allow'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource dataIngestionContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'data-ingestion'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-ingest-storage-diag'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the ingestion storage account.')
output storageAccountId string = storageAccount.id

@description('The name of the ingestion storage account.')
output storageAccountName string = storageAccount.name

@description('The primary blob endpoint URI.')
output storageAccountUri string = storageAccount.properties.primaryEndpoints.blob

@description('The name of the data-ingestion container.')
output containerName string = dataIngestionContainer.name
