targetScope = 'subscription'

@description('Remote Desktop VNET Resource Group Name')
param remoteDesktopVnetRgName string

@description('Remote Desktop VNET Name')
param remoteDesktopVnetName string

@description('Hub VNET Name')
param hubVnetName string

@description('Hub VNET Resource ID')
param hubVnetId string

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
