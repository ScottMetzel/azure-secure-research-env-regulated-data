@description('Azure region for the Key Vault.')
param location string

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the subnet where the private endpoint will be placed.')
param subnetId string

@description('Resource ID of the VNet. Reserved for future use (e.g. additional DNS zone links or peering checks).')
#disable-next-line no-unused-params
param vnetId string

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Azure AD tenant ID.')
param tenantId string = tenant().tenantId

@description('Soft-delete retention days (minimum 7).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

// ── Key Vault ─────────────────────────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${environmentName}-kv-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    // With publicNetworkAccess disabled, all access is via the private endpoint only.
    // networkAcls are still defined for the bypass setting (allows Azure-internal traffic
    // such as Azure Monitor), but virtualNetworkRules are omitted as they are not
    // evaluated when publicNetworkAccess is 'Disabled'.
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

// ── Private DNS Zone (vault) ──────────────────────────────────────────────────

resource kvDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.vaultcore.azure.net'
}

// ── Private Endpoint ──────────────────────────────────────────────────────────

resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${environmentName}-kv-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: '${environmentName}-kv-plsc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource kvDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  name: 'kvDnsZoneGroup'
  parent: kvPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: kvDnsZone.id
        }
      }
    ]
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-kv-diag'
  scope: keyVault
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

@description('The resource ID of the Key Vault.')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault.')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault.')
output keyVaultUri string = keyVault.properties.vaultUri
