targetScope = 'subscription'

@description('Researcher VNET Resource Group Name')
param researcherVnetRgName string = 'Dev-RG-Network-01'

@description('Researcher VNET Name')
param researcherVnetName string = 'Dev-VNET-Researcher-01'

@description('Hub VNET Name')
param hubVnetName string = 'Dev-VNET-Hub-01'

@description('Hub VNET Resource ID')
param hubVnetId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Network-01/providers/Microsoft.Network/virtualNetworks/Dev-VNET-Hub-01'

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

// ── Resources via Modules ───────────────────────────────────────────────────────────
module researcherSpokeToHubPeering '../network/vnetPeering.bicep' = {
  name: 'researcherSpokeToHubPeering_${deploymentTimestamp}'
  scope: resourceGroup(researcherVnetRgName)
  params: {
    localVnetName: researcherVnetName
    remoteVnetName: hubVnetName
    remoteVnetId: hubVnetId
  }
}
