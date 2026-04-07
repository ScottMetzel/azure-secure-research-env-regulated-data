targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@allowed([
  'Demo'
  'Dev'
  'Test'
  'Staging'
  'Prod'
])
param environmentName string = 'Prod'

@description('Address prefix for the Researcher Spoke Azure Virtual Network.')
param net_researcher_vnetAddressPrefix string = '10.100.56.0/21'

param net_researcher_webSubnetPrefix string = '10.100.56.64/27'
param net_researcher_appSubnetPrefix string = '10.100.56.96/27'
param net_researcher_dbSubnetPrefix string = '10.100.56.128/27'

@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param net_researcher_storageSubnetPrefix string = '10.100.56.160/27'

param net_researcher_webVNETIntegrationSubnetPrefix string = '10.100.56.192/27'

@description('Address prefix for the first Data Science Server subnet.')
param net_researcher_ServerSubnetPrefix string = '10.100.61.0/28'

@description('The private IP address of the Azure Firewall deployed in the hub, used as the next hop for forced tunneling from the Remote Desktop Server subnet.')
param net_hub_azureFirewallPrivateIP string = '10.100.0.4'

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array = [
  '168.63.129.16'
]

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Spoke VNET resource group — contains the spoke Virtual Network (including Researcher VM subnet, and subnets for resources with Private Endpoints which researchers will access).')
resource spokeVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Network-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────
module researcherNetworking '../network/networking_researcher.bicep' = {
  name: 'researcherNetworking_${deploymentTimestamp}'
  scope: spokeVNETRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetAddressPrefix: net_researcher_vnetAddressPrefix
    webSubnetPrefix: net_researcher_webSubnetPrefix
    appSubnetPrefix: net_researcher_appSubnetPrefix
    dbSubnetPrefix: net_researcher_dbSubnetPrefix
    storageSubnetPrefix: net_researcher_storageSubnetPrefix
    webVNETIntegrationSubnetPrefix: net_researcher_webVNETIntegrationSubnetPrefix
    researcherServerSubnetPrefix: net_researcher_ServerSubnetPrefix
    vNETDNSServers: vNETDNSServers
    azureFirewallPrivateIp: net_hub_azureFirewallPrivateIP
  }
}

// ── Outputs ───────────────────────────────────────────────────────────
@description('The name of the Researcher VNET Resource Group.')
output researcherVnetResourceGroupName string = spokeVNETRG.name

@description('Researcher VNET ID.')
output researcherVnetId string = researcherNetworking.outputs.vnetId

@description('Researcher VNET Name.')
output researcherVnetName string = researcherNetworking.outputs.vnetName

@description('Researcher NSG ID.')
output researcherNsgId string = researcherNetworking.outputs.nsgId

@description('The resource ID of the Web01 subnet.')
output Web01SubnetId string = researcherNetworking.outputs.Web01SubnetId

@description('The resource ID of the App01 subnet.')
output App01SubnetId string = researcherNetworking.outputs.App01SubnetId

@description('The resource ID of the DB01 subnet.')
output DB01SubnetId string = researcherNetworking.outputs.DB01SubnetId

@description('The resource ID of the Storage01 subnet.')
output Storage01SubnetId string = researcherNetworking.outputs.Storage01SubnetId

@description('The resource ID of the KeyVault01 subnet.')
output KeyVault01SubnetId string = researcherNetworking.outputs.KeyVault01SubnetId

@description('The resource ID of the WebVNETIntegration01 subnet.')
output WebVNETIntegration01SubnetId string = researcherNetworking.outputs.WebVNETIntegration01SubnetId

@description('The resource ID of the ResearcherVMSubnet01 subnet.')
output ResearcherVMSubnet01SubnetId string = researcherNetworking.outputs.ResearcherVMSubnet01SubnetId
