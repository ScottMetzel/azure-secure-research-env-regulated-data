@description('Azure region for the secure storage account.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the subnet where the private endpoint will be placed.')
param subnetId string

@description('Resource ID of the VNet. Reserved for future use (e.g. additional DNS zone links).')
#disable-next-line no-unused-params
param vnetId string

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Optional resource ID of a Key Vault for customer-managed keys. Leave empty to use Microsoft-managed keys.')
#disable-next-line no-unused-params
param keyVaultId string = ''

// ── Storage Account ───────────────────────────────────────────────────────────

var storageAccountName = toLower(take('${replace(environmentName, '-', '')}secure${uniqueString(resourceGroup().id)}', 24))

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
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
  }
}

resource researchDataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'research-data'
  parent: blobService
  properties: {
    publicAccess: 'None'
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}

// Lock the immutability policy so data cannot be deleted or overwritten.
resource immutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2023-01-01' = {
  name: 'default'
  parent: researchDataContainer
  properties: {
    immutabilityPeriodSinceCreationInDays: 1
    allowProtectedAppendWrites: false
  }
}

// ── Private DNS Zone ──────────────────────────────────────────────────────────

resource blobDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  // Zone name is mandated by Azure Private Link and cannot be changed.
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.blob.core.windows.net'
}

// ── Private Endpoint ──────────────────────────────────────────────────────────

resource secureStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${environmentName}-secure-storage-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${environmentName}-secure-storage-plsc'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource secureStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'secureStorageDnsZoneGroup'
  parent: secureStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: blobDnsZone.id
        }
      }
    ]
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-secure-storage-diag'
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

@description('The resource ID of the secure storage account.')
output storageAccountId string = storageAccount.id

@description('The name of the secure storage account.')
output storageAccountName string = storageAccount.name

@description('The primary blob endpoint URI.')
output storageAccountUri string = storageAccount.properties.primaryEndpoints.blob

@description('The name of the research-data container.')
output containerName string = researchDataContainer.name
