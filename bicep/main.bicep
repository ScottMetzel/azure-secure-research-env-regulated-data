targetScope = 'subscription'

// ── Parameters ────────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@allowed([
  'Dev'
  'Test'
  'Staging'
  'Prod'
])
param environmentName string = 'Prod'

@description('Tag - Workload Name.')
param workloadName string = 'SRERD'

@description('Tag - Solution Owner.')
param solutionOwner string = 'owner@example.com'

@description('Local administrator username for VMs.')
param adminUsername string = 'azureuser'

@description('Local administrator password for VMs.')
@secure()
param adminPassword string = ''

@description('Options: Bastion or AVD. Determines whether to deploy Azure Bastion with a virtual machine or Azure Virtual Desktop for remote access to the environment. Default is Bastion.')
@allowed([
  'Bastion'
  'AVD'
])
param BastionOrAVD string = 'Bastion'

@description('Subscription ID where the research environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param researcherSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('Subscription ID where the hub VNet (with Firewall) will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param hubSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('Subscription ID where the Bastion and virtual desktop environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param virtualDesktopSubscriptionID string = '00000000-0000-0000-0000-000000000000'

@description('VM size for Data Science VMs.')
param researcherVMSize string = 'Standard_D4ds_v5'

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(1)
param researcherVMCount int = 1

@description('The email address of the data approver, who will receive notifications and approval requests when researchers attempt to upload data to the secure environment.')
param dataApproverEmail string = 'dataapprover@example.com'

#disable-next-line no-hardcoded-env-urls
param blobPrivateLinkZoneName string = 'privatelink.blob.core.windows.net'

param privateDnsZoneNames array = [
  'privatelink.vaultcore.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.azureml.ms'
]

// ── Hub VNET Parameters ───────────────────────────────────────────────────────────
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

// ── Remote Desktop VNET Parameters ───────────────────────────────────────────────────────────
@description('Address prefix for the virtual network.')
param net_RemoteDesktop_vnetAddressPrefix string = '10.100.40.0/21'

@description('Address prefix for the Azure Bastion subnet.')
param net_RemoteDesktop_bastionSubnetPrefix string = '10.100.40.0/26'

param net_RemoteDesktop_webSubnetPrefix string = '10.100.40.64/27'
param net_RemoteDesktop_appSubnetPrefix string = '10.100.40.96/27'
param net_RemoteDesktop_dbSubnetPrefix string = '10.100.40.128/27'
@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param net_RemoteDesktop_storageSubnetPrefix string = '10.100.40.160/27'

param net_RemoteDesktop_webVNETIntegrationSubnetPrefix string = '10.100.40.192/27'

@description('Address prefix for the Remote Desktop Server subnet.')
param net_RemoteDesktop_rdServerSubnetPrefix string = '10.100.41.0/24'

@description('Address prefix for the first Azure Virtual Desktop subnet.')
param net_RemoteDesktop_avdSubnetPrefix string = '10.100.42.0/24'

// ── Researcher VNET Parameters ───────────────────────────────────────────────────────────
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

@description('The date and time in UTC format. Used as part of the deployment name')
param deploymentTimestamp string = utcNow()

// ── Variables ───────────────────────────────────────────────────────────
var privateDnsZoneNamesArray = concat([blobPrivateLinkZoneName], privateDnsZoneNames)

var blobStoragePrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  blobPrivateLinkZoneName
)

var keyVaultPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.vaultcore.azure.net'
)

var dataFactoryPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.datafactory.azure.net'
)

var azureMLPrivateDnsZoneId = resourceId(
  hubSubscriptionID,
  hubSubscription.outputs.privateDNSZonesRGName,
  'Microsoft.Network/privateDnsZones',
  'privatelink.azureml.ms'
)

@description('Azure DNS Private Resolver Inbound Endpoint Static Private IP Address. Must be within the address range of the AzDNSPRInbound01 subnet defined in the hub virtual network.')
var azDNSPRInboundStaticIPCIDR = cidrSubnet(net_hub_azDNSPrivateResolverInboundSubnetPrefix, 32, 4)

var net_hub_azDNSPRInboundStaticIP = first(split(azDNSPRInboundStaticIPCIDR, '/'))

@description('Azure Firewall Private IP Address. This is the 5th usable IP in the AzureFirewallSubnet.')
var firewallPrivateIPCIDR = cidrSubnet(net_hub_firewallSubnetPrefix, 32, 4)

var net_hub_azureFirewallPrivateIP = first(split(firewallPrivateIPCIDR, '/'))

var vNETDNSServers = [
  net_hub_azureFirewallPrivateIP
]

@description('Tags applied to every resource.')
var tags = {
  Description: 'Secure Research Environment for Regulated Data'
  Environment: environmentName
  Owner: solutionOwner
  WorkloadName: workloadName
}

// ── Subscription deployments ───────────────────────────────────────────────────────────

@description('Hub Subscription - Contains the hub VNET and Azure Firewall.')
module hubSubscription 'modules/subscriptions/hubSubscription.bicep' = {
  name: 'hubSubscription_${deploymentTimestamp}'
  scope: subscription(hubSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    privateDnsZoneNamesArray: privateDnsZoneNamesArray
    vNETDNSServers: vNETDNSServers
    net_hub_vnetAddressPrefix: net_hub_vnetAddressPrefix
    net_hub_gatewaySubnetPrefix: net_hub_gatewaySubnetPrefix
    net_hub_firewallSubnetPrefix: net_hub_firewallSubnetPrefix
    net_hub_azDNSPrivateResolverInboundSubnetPrefix: net_hub_azDNSPrivateResolverInboundSubnetPrefix
    net_hub_azDNSPrivateResolverOutboundSubnetPrefix: net_hub_azDNSPrivateResolverOutboundSubnetPrefix
    net_hub_azDNSPRInboundStaticIP: net_hub_azDNSPRInboundStaticIP
    net_hub_azureFirewallPrivateIP: net_hub_azureFirewallPrivateIP
    deploymentTimestamp: deploymentTimestamp
    tags: tags
  }
}

@description('Virtual Desktop Subscription - Contains the Bastion and VM or Azure Virtual Desktop environment.')
module virtualDesktopSubscription 'modules/subscriptions/virtualDesktopSubscription.bicep' = {
  name: 'virtualDesktopSubscription_${deploymentTimestamp}'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    BastionOrAVD: BastionOrAVD
    vNETDNSServers: vNETDNSServers
    adminUsername: adminUsername
    adminPassword: adminPassword
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    net_RemoteDesktop_vnetAddressPrefix: net_RemoteDesktop_vnetAddressPrefix
    net_RemoteDesktop_bastionSubnetPrefix: net_RemoteDesktop_bastionSubnetPrefix
    net_RemoteDesktop_webSubnetPrefix: net_RemoteDesktop_webSubnetPrefix
    net_RemoteDesktop_appSubnetPrefix: net_RemoteDesktop_appSubnetPrefix
    net_RemoteDesktop_dbSubnetPrefix: net_RemoteDesktop_dbSubnetPrefix
    net_RemoteDesktop_storageSubnetPrefix: net_RemoteDesktop_storageSubnetPrefix
    net_RemoteDesktop_webVNETIntegrationSubnetPrefix: net_RemoteDesktop_webVNETIntegrationSubnetPrefix
    net_RemoteDesktop_rdServerSubnetPrefix: net_RemoteDesktop_rdServerSubnetPrefix
    net_RemoteDesktop_avdSubnetPrefix: net_RemoteDesktop_avdSubnetPrefix
    net_hub_azureFirewallPrivateIP: net_hub_azureFirewallPrivateIP
    deploymentTimestamp: deploymentTimestamp
    tags: tags
  }
}

@description('Researcher Subscription - Contains the research VM, compute resources, and data storage.')
module researcherSubscription 'modules/subscriptions/researcherSubscription.bicep' = {
  name: 'researcherSubscription_${deploymentTimestamp}'
  scope: subscription(researcherSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    net_researcher_vnetAddressPrefix: net_researcher_vnetAddressPrefix
    net_researcher_webSubnetPrefix: net_researcher_webSubnetPrefix
    net_researcher_appSubnetPrefix: net_researcher_appSubnetPrefix
    net_researcher_dbSubnetPrefix: net_researcher_dbSubnetPrefix
    net_researcher_storageSubnetPrefix: net_researcher_storageSubnetPrefix
    net_researcher_webVNETIntegrationSubnetPrefix: net_researcher_webVNETIntegrationSubnetPrefix
    net_researcher_ServerSubnetPrefix: net_researcher_ServerSubnetPrefix
    vNETDNSServers: vNETDNSServers
    adminUsername: adminUsername
    adminPassword: adminPassword
    researcherVMSize: researcherVMSize
    researcherVMCount: researcherVMCount
    dataApproverEmail: dataApproverEmail
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    net_hub_azureFirewallPrivateIP: net_hub_azureFirewallPrivateIP
    blobStoragePrivateDnsZoneId: blobStoragePrivateDnsZoneId
    keyVaultPrivateDnsZoneId: keyVaultPrivateDnsZoneId
    dataFactoryPrivateDnsZoneId: dataFactoryPrivateDnsZoneId
    azureMLPrivateDnsZoneId: azureMLPrivateDnsZoneId
    deploymentTimestamp: deploymentTimestamp
    tags: tags
  }
}

// ── VNet Peerings ─────────────────────────────────────────────────────────────
// Peerings are deployed as separate modules to avoid a circular dependency
// between the hub and spoke VNet modules.

module hubtoVirtualDesktopSpokePeering 'modules/subscriptions/hubSubscriptionVnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering_${deploymentTimestamp}'
  scope: subscription(hubSubscriptionID)
  params: {
    hubVnetRgName: hubSubscription.outputs.hubVNETRGName
    hubVnetName: hubSubscription.outputs.hubVNETName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    remoteDesktopVnetId: virtualDesktopSubscription.outputs.rdVnetId
    researcherVnetId: researcherSubscription.outputs.researcherVnetId
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
    deploymentTimestamp: deploymentTimestamp
  }
}

module virtualDesktopToHubPeering 'modules/subscriptions/virtualDesktopSubscriptionVnetPeering.bicep' = {
  name: 'virtualDesktopToHubPeering_${deploymentTimestamp}'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    remoteDesktopVnetRgName: virtualDesktopSubscription.outputs.rdVnetResourceGroupName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
    deploymentTimestamp: deploymentTimestamp
  }
}

module researcherToHubPeering 'modules/subscriptions/researcherSubscriptionVnetPeering.bicep' = {
  name: 'researcherToHubPeering_${deploymentTimestamp}'
  scope: subscription(researcherSubscriptionID)
  params: {
    researcherVnetRgName: researcherSubscription.outputs.researcherVnetResourceGroupName
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
    deploymentTimestamp: deploymentTimestamp
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Resource ID of the Firewall.')
output firewallResourceID string = hubSubscription.outputs.firewallId

@description('Resource ID of the Bastion.')
output bastionResourceID string = ((BastionOrAVD == 'Bastion')
  ? virtualDesktopSubscription.outputs.bastionResourceId
  : 'Bastion deployment not selected, no Bastion resource created.')

@description('Resource ID of the hub virtual network.')
output hubVnetId string = hubSubscription.outputs.hubVNETId

@description('Resource ID of the spoke virtual network.')
output remoteDesktopVnetId string = virtualDesktopSubscription.outputs.rdVnetId

@description('Resource ID of the research virtual network.')
output researchVnetId string = researcherSubscription.outputs.researcherVnetId

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = hubSubscription.outputs.logAnalyticsWorkspaceResourceId
