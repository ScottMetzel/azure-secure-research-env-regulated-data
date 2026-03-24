@description('Azure region for all resources.')
param location string = 'westus2'

@description('Resource ID of the Virtual Network to link the private DNS zones to.')
param vnetId string

param privateDnsZoneNamesArray array

@description('Tags to apply to all resources.')
param tags object

// ── Variables ─────────────────────────────────────────────────────────
var hubVNETName string = last(split(vnetId, '/'))

// ── Private DNS Zones ─────────────────────────────────────────────────────────
resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [
  for zone in privateDnsZoneNamesArray: {
    name: zone
    location: 'global'
    tags: tags
  }
]

resource dnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in privateDnsZoneNamesArray: {
    name: '${hubVNETName}_Link_${location}'
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
output privateDnsZoneIds array = [for (zone, i) in privateDnsZoneNamesArray: dnsZones[i].id]

@description('The names of the private DNS zones (used to create additional VNet links).')
output privateDnsZoneNames array = privateDnsZoneNamesArray
