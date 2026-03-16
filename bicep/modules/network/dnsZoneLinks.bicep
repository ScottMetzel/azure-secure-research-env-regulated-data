// dnsZoneLinks.bicep
// Creates virtualNetworkLinks for each private DNS zone in this resource group,
// linking them to an additional VNet (e.g., the hub VNet). This module must be
// deployed in the same resource group as the private DNS zones.

@description('Environment name used as a prefix for link names.')
@minLength(1)
@maxLength(20)
param environmentName string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the VNet to link to the private DNS zones.')
param vnetId string

@description('Array of private DNS zone names to link (e.g. ["privatelink.blob.core.windows.net", ...]).')
param dnsZoneNames array

// ── Existing DNS Zones ────────────────────────────────────────────────────────

resource existingDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [
  for zoneName in dnsZoneNames: {
    name: zoneName
  }
]

// ── VNet Links ────────────────────────────────────────────────────────────────

resource hubVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for (zoneName, i) in dnsZoneNames: {
    name: '${environmentName}-hub-link'
    parent: existingDnsZones[i]
    location: 'global'
    tags: tags
    properties: {
      virtualNetwork: { id: vnetId }
      registrationEnabled: false
    }
  }
]
