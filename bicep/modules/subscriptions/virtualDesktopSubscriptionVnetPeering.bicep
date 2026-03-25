targetScope = 'subscription'

@description('Remote Desktop VNET Resource Group Name')
param remoteDesktopVnetRgName string = 'Dev-RG-Network-01'

@description('Remote Desktop VNET Name')
param remoteDesktopVnetName string = 'Dev-VNET-RemoteDesktop-01'

@description('Hub VNET Name')
param hubVnetName string = 'Dev-VNET-Hub-01'

@description('Hub VNET Resource ID')
param hubVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01'

// ── Resources via Modules ───────────────────────────────────────────────────────────
module remoteDesktopSpokeToHubPeering '../network/vnetPeering.bicep' = {
  name: 'remoteDesktopSpokeToHubPeering'
  scope: resourceGroup(remoteDesktopVnetRgName)
  params: {
    localVnetName: remoteDesktopVnetName
    remoteVnetName: hubVnetName
    remoteVnetId: hubVnetId
  }
}
