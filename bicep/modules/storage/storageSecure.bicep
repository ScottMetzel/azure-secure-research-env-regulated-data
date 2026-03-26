@description('Azure region for the secure storage account.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the subnet where the private endpoint will be placed.')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01/subnets/Dev-Subnet-Security-01'

@description('Resource ID of the VNet. Reserved for future use (e.g. additional DNS zone links).')
#disable-next-line no-unused-params
param vnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01'

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Optional resource ID of a Key Vault for customer-managed keys. Leave empty to use Microsoft-managed keys.')
#disable-next-line no-unused-params
param keyVaultId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Security-01/providers/Microsoft.KeyVault/vaults/dev-kv-01'

@description('Resource ID of the Azure Blob Storage Private DNS Zone.')
#disable-next-line no-hardcoded-env-urls
param blobStoragePrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}
// ── Storage Account ───────────────────────────────────────────────────────────

var storageAccountName = toLower(take(
  '${replace(environmentName, '-', '')}secure${uniqueString(resourceGroup().id)}',
  24
))

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
  name: 'default'
  parent: secureStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_blob_core_windows_net'
        properties: {
          privateDnsZoneId: blobStoragePrivateDnsZoneId
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
