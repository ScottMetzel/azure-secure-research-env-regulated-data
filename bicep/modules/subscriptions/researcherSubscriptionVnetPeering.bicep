targetScope = 'subscription'

@description('Researcher VNET Resource Group Name')
param researcherVnetRgName string

@description('Researcher VNET Name')
param researcherVnetName string

@description('Hub VNET Name')
param hubVnetName string

@description('Hub VNET Resource ID')
param hubVnetId string

// ── Resources via Modules ───────────────────────────────────────────────────────────
module researcherSpokeToHubPeering '../network/vnetPeering.bicep' = {
  name: 'researcherSpokeToHubPeering'
  scope: resourceGroup(researcherVnetRgName)
  params: {
    localVnetName: researcherVnetName
    remoteVnetName: hubVnetName
    remoteVnetId: hubVnetId
  }
}
