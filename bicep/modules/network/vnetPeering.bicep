// vnetPeering.bicep
// Creates a single VNet peering on a parent VNet toward a remote VNet.
// Deploy two instances (one scoped to each VNet's resource group) to establish
// a bidirectional peering.

@description('Name of the local virtual network that will own this peering.')
param localVnetName string = 'hub-vnet'

@description('Name of the remote virtual network to peer with.')
param remoteVnetName string = 'remote-desktop-spoke-vnet'

@description('Resource ID of the remote virtual network to peer with.')
param remoteVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01'

@description('Allow forwarded traffic through the peering.')
param allowForwardedTraffic bool = true
// ── Variables ───────────────────────────────────────────────────────────────
var peeringName = '${localVnetName}_to_${remoteVnetName}'

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
