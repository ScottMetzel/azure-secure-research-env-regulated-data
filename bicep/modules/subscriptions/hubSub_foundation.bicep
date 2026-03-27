targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Address prefix for the hub virtual network.')
param net_hub_vnetAddressPrefix string = '10.100.0.0/23'

@description('Address prefix for the GatewaySubnet (minimum /28).')
param net_hub_gatewaySubnetPrefix string = '10.100.0.0/26'

@description('Address prefix for AzureFirewallSubnet (minimum /26).')
param net_hub_firewallSubnetPrefix string = '10.100.0.64/26'

@description('Address prefix for Azure DNS Private Resolver Inbound Subnet (minimum /28).')
param net_hub_azDNSPrivateResolverInboundSubnetPrefix string = '10.100.0.128/28'

@description('Address prefix for Azure DNS Private Resolver Outbound Subnet (minimum /28).')
param net_hub_azDNSPrivateResolverOutboundSubnetPrefix string = '10.100.0.144/28'

@description('The string array of DNS servers to use on the Virtual Network.')
param vNETDNSServers array = [
  '168.63.129.16'
]

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

@description('Tags applied to every resource.')
param tags object = {
  WorkloadName: 'SRERD'
  Environment: 'Dev'
}

// ── Variables ───────────────────────────────────────────────────────────
// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Resource Group for the Hub VNET — contains the hub Virtual Network and Firewall.')
resource hubVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Network-01'
  location: location
  tags: tags
}

@description('Resource Group for Microsoft Sentinel.')
resource sentinelRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Sentinel-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────
module hubVNET '../network/networking_hub.bicep' = {
  name: 'hubVNET_${deploymentTimestamp}'
  scope: resourceGroup(hubVNETRG.name)
  params: {
    location: location
    environmentName: environmentName
    vNETDNSServers: vNETDNSServers
    hubVNETAddressPrefix: net_hub_vnetAddressPrefix
    gatewaySubnetPrefix: net_hub_gatewaySubnetPrefix
    firewallSubnetPrefix: net_hub_firewallSubnetPrefix
    azDNSPrivateResolverInboundSubnet: net_hub_azDNSPrivateResolverInboundSubnetPrefix
    azDNSPrivateResolverOutboundSubnet: net_hub_azDNSPrivateResolverOutboundSubnetPrefix
    tags: tags
  }
}

module logAnalytics '../monitoring/logAnalytics.bicep' = {
  name: 'logAnalytics_${deploymentTimestamp}'
  scope: resourceGroup(sentinelRG.name)
  params: {
    location: location
    environmentName: environmentName
    workspaceName: '${environmentName}-LAW-SOC-01'
    tags: tags
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
@description('The name of the hub virtual network resource group.')
output hubVNETRGName string = hubVNETRG.name

@description('Hub VNET Name')
output hubVNETName string = hubVNET.outputs.HubVNETName

@description('Hub VNET Resource ID')
output hubVNETId string = hubVNET.outputs.HubVNETid

@description('Hub VNET DNS Private Resolver Inbound Subnet ID')
output hubVNETDNSPRInboundSubnetId string = hubVNET.outputs.HubDNSPRInboundSubnetId

@description('Hub VNET Azure Firewall Subnet ID')
output hubVNETFirewallSubnetId string = hubVNET.outputs.HubFirewallSubnetId

@description('The resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceResourceId string = logAnalytics.outputs.workspaceResourceId

@description('The name of the Log Analytics Workspace.')
output logAnalyticsWorkspaceName string = logAnalytics.outputs.workspaceName
