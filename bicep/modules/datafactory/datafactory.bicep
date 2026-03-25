@description('Azure region for the Data Factory.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the subnet where the private endpoint will be placed.')
param subnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01/subnets/Dev-Subnet-DataFactory'

@description('Resource ID of the VNet. Reserved for future use (e.g. additional managed private endpoints).')
#disable-next-line no-unused-params
param vnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01'

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Resource ID of the secure storage account.')
param secureStorageAccountId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Security-01/providers/Microsoft.Storage/storageAccounts/devsecstorageacct01'

@description('Name of the secure storage account.')
param secureStorageAccountName string = 'devsecstorageacct01'

@description('Resource ID of the Key Vault.')
param keyVaultId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Security-01/providers/Microsoft.KeyVault/vaults/dev-kv-01'

@description('Resource ID of the Data Factory Private DNS Zone.')
param dataFactoryPrivateDnsZoneId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/privateDnsZones/privatelink.datafactory.azure.net'

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Built-in role definition IDs ──────────────────────────────────────────────

var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// ── Data Factory ──────────────────────────────────────────────────────────────

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: '${environmentName}-adf'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource adfManagedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: 'default'
  parent: dataFactory
  properties: {}
}

resource adfAutoResolveIr 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: 'AutoResolveIntegrationRuntime'
  parent: dataFactory
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: adfManagedVnet.name
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

// ── Private Endpoint ──────────────────────────────────────────────────────────

resource adfPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${environmentName}-adf-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${environmentName}-adf-plsc'
        properties: {
          privateLinkServiceId: dataFactory.id
          groupIds: ['dataFactory']
        }
      }
    ]
  }
}

resource adfDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'adfDnsZoneGroup'
  parent: adfPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-datafactory-azure-net'
        properties: {
          privateDnsZoneId: dataFactoryPrivateDnsZoneId
        }
      }
    ]
  }
}

// ── Role Assignments ──────────────────────────────────────────────────────────

resource secureStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: secureStorageAccountName
}

resource secureStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(secureStorageAccountId, dataFactory.id, storageBlobDataContributorRoleId)
  scope: secureStorageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultResource 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource kvSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, dataFactory.id, keyVaultSecretsUserRoleId)
  scope: keyVaultResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource adfDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-adf-diag'
  scope: dataFactory
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
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the Data Factory.')
output dataFactoryId string = dataFactory.id

@description('The name of the Data Factory.')
output dataFactoryName string = dataFactory.name

@description('The principal ID of the Data Factory managed identity.')
output dataFactoryPrincipalId string = dataFactory.identity.principalId
