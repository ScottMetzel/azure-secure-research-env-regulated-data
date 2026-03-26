targetScope = 'subscription'

@description('Hub VNET Resource Group Name')
param hubVnetRgName string = 'hub-vnet-rg'

@description('Hub VNET Name')
param hubVnetName string = 'hub-vnet'

@description('Remote Desktop VNET Name')
param remoteDesktopVnetName string = 'virtual-desktop-spoke-vnet'

@description('Remote Desktop Resource ID')
param remoteDesktopVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-RemoteDesktop-01'

@description('Researcher VNET Name')
param researcherVnetName string = 'researcher-spoke-vnet'

@description('Resource ID of the Rearcher VNET')
param researcherVnetId string = ''

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

// ── Resources via Modules ───────────────────────────────────────────────────────────
module hubtoVirtualDesktopSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering_${deploymentTimestamp}'
  scope: resourceGroup(hubVnetRgName)
  params: {
    localVnetName: hubVnetName
    remoteVnetName: remoteDesktopVnetName
    remoteVnetId: remoteDesktopVnetId
  }
}

module hubtoResearcherSpokePeering '../network/vnetPeering.bicep' = {
  name: 'hubtoResearcherSpokePeering_${deploymentTimestamp}'
  scope: resourceGroup(hubVnetRgName)
  params: {
    localVnetName: hubVnetName
    remoteVnetName: researcherVnetName
    remoteVnetId: researcherVnetId
  }
}
