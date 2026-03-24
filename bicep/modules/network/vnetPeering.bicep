// vnetPeering.bicep
// Creates a single VNet peering on a parent VNet toward a remote VNet.
// Deploy two instances (one scoped to each VNet's resource group) to establish
// a bidirectional peering.

@description('Name of the local virtual network that will own this peering.')
param localVnetName string

@description('Name of the remote virtual network to peer with.')
param remoteVnetName string

@description('Resource ID of the remote virtual network to peer with.')
param remoteVnetId string

@description('Allow forwarded traffic through the peering.')
param allowForwardedTraffic bool = true

// ── Variables ───────────────────────────────────────────────────────────────
var peeringName = '${localVnetName}-to-${remoteVnetName}'

// ── Local VNet (existing) ─────────────────────────────────────────────────────

resource localVnet 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: localVnetName
}

// ── Peering ───────────────────────────────────────────────────────────────────

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = {
  name: peeringName
  parent: localVnet
  properties: {
    remoteVirtualNetwork: { id: remoteVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the peering.')
output peeringId string = peering.id
