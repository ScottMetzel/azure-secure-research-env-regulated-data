targetScope = 'subscription'

@description('Hub VNET Resource Group Name')
param hubVnetRgName string

@description('Hub VNET Name')
param hubVnetName string

@description('Remote Desktop VNET Name')
param remoteDesktopVnetName string

@description('Remote Desktop Resource ID')
param remoteDesktopVnetId string

@description('Researcher VNET Name')
param researcherVnetName string

@description('Resource ID of the Rearcher VNET')
param researcherVnetId string

// ── Resources via Modules ───────────────────────────────────────────────────────────
module hubtoVirtualDesktopSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering'
  scope: resourceGroup(hubVnetRgName)
  params: {
    localVnetName: hubVnetName
    remoteVnetName: remoteDesktopVnetName
    remoteVnetId: remoteDesktopVnetId
  }
}

module hubtoResearcherSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoResearcherSpokePeering'
  scope: resourceGroup(hubVnetRgName)
  params: {
    localVnetName: hubVnetName
    remoteVnetName: researcherVnetName
    remoteVnetId: researcherVnetId
  }
}
