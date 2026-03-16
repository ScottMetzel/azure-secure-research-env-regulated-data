// vnetPeering.bicep
// Creates a single VNet peering on a parent VNet toward a remote VNet.
// Deploy two instances (one scoped to each VNet's resource group) to establish
// a bidirectional peering.

@description('Name of the local virtual network that will own this peering.')
param localVnetName string

@description('Resource ID of the remote virtual network to peer with.')
param remoteVnetId string

@description('A short suffix appended to the peering name to identify the direction (e.g. "to-hub" or "to-spoke").')
param peeringSuffix string

@description('Allow forwarded traffic through the peering.')
param allowForwardedTraffic bool = true

// ── Local VNet (existing) ─────────────────────────────────────────────────────

resource localVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: localVnetName
}

// ── Peering ───────────────────────────────────────────────────────────────────

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  name: '${localVnetName}-${peeringSuffix}'
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
