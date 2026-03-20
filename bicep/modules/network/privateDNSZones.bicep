@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Resource ID of the Virtual Network to link the private DNS zones to.')
param vnetId string

@description('Tags to apply to all resources.')
param tags object

// ── Private DNS Zones ─────────────────────────────────────────────────────────

// These zone names are mandated by Azure Private Link — they cannot be changed.
#disable-next-line no-hardcoded-env-urls
var blobPrivateLinkZone = 'privatelink.blob.core.windows.net'

var privateDnsZones = [
  blobPrivateLinkZone
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [
  for zone in privateDnsZones: {
    name: zone
    location: 'global'
    tags: tags
  }
]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in privateDnsZones: {
    name: '${environmentName}-link'
    parent: dnsZones[i]
    location: 'global'
    tags: tags
    properties: {
      virtualNetwork: { id: vnetId }
      registrationEnabled: false
      resolutionPolicy: 'NxDomainRedirect'
    }
  }
]

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource IDs of the private DNS zones.')
output privateDnsZoneIds array = [for (zone, i) in privateDnsZones: dnsZones[i].id]

@description('The names of the private DNS zones (used to create additional VNet links).')
output privateDnsZoneNames array = privateDnsZones
