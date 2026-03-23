targetScope = 'subscription'

// ── Parameters ────────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'production'

@description('Tag - Workload Name.')
param workloadName string = 'SILO'

@description('Tags applied to every resource.')
param tags object = {
  workloadName: workloadName
  environment: environmentName
}

@description('Local administrator username for VMs.')
param adminUsername string

@description('Local administrator password for VMs.')
@secure()
param adminPassword string

@description('Subscription ID where the research environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param researcherSubscriptionID string

@description('Subscription ID where the hub VNet (with Firewall) will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param hubSubscriptionID string

@description('Subscription ID where the Bastion and virtual desktop environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param virtualDesktopSubscriptionID string

@description('VM size for Data Science VMs.')
param researcherVMSize string = 'Standard_D8s_v5'

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(1)
param researcherVMCount int = 1

@description('The email address of the data approver, who will receive notifications and approval requests when researchers attempt to upload data to the secure environment.')
param dataApproverEmail string

// ── Subscription deployments ───────────────────────────────────────────────────────────

@description('Hub Subscription - Contains the hub VNET and Azure Firewall.')
module hubSubscription 'modules/subscriptions/hubSubscription.bicep' = {
  name: 'hubSubscription'
  scope: subscription(hubSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

@description('Virtual Desktop Subscription - Contains the Bastion and virtual desktop environment.')
module virtualDesktopSubscription 'modules/subscriptions/virtualDesktopSubscription.bicep' = {
  name: 'virtualDesktopSubscription'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    adminUsername: adminUsername
    adminPassword: adminPassword
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    azureFirewallPrivateIp: hubSubscription.outputs.firewallPrivateIp
    tags: tags
  }
}

@description('Researcher Subscription - Contains the research VM, compute resources, and data storage.')
module researcherSubscription 'modules/subscriptions/researcherSubscription.bicep' = {
  name: 'researcherSubscription'
  scope: subscription(researcherSubscriptionID)
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    adminUsername: adminUsername
    adminPassword: adminPassword
    researcherVMSize: researcherVMSize
    researcherVMCount: researcherVMCount
    dataApproverEmail: dataApproverEmail
    logAnalyticsWorkspaceId: hubSubscription.outputs.logAnalyticsWorkspaceResourceId
    azureFirewallPrivateIp: hubSubscription.outputs.firewallPrivateIp
  }
}

// ── VNet Peerings ─────────────────────────────────────────────────────────────
// Peerings are deployed as separate modules to avoid a circular dependency
// between the hub and spoke VNet modules.

module hubtoVirtualDesktopSpokePeering 'modules/subscriptions/hubSubscriptionVnetPeering.bicep' = {
  name: 'hubtoVirtualDesktopSpokePeering'
  scope: subscription(hubSubscriptionID)
  params: {
    hubVnetRgName: hubSubscription.outputs.hubVNETRGName
    hubVnetName: hubSubscription.outputs.hubVNETName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    remoteDesktopVnetId: virtualDesktopSubscription.outputs.rdVnetId
    researcherVnetId: researcherSubscription.outputs.researcherVnetId
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
  }
}

module virtualDesktopToHubPeering 'modules/subscriptions/virtualDesktopSubscriptionVnetPeering.bicep' = {
  name: 'virtualDesktopToHubPeering'
  scope: subscription(virtualDesktopSubscriptionID)
  params: {
    remoteDesktopVnetRgName: virtualDesktopSubscription.outputs.rdVnetResourceGroupName
    remoteDesktopVnetName: virtualDesktopSubscription.outputs.rdVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
  }
}

module researcherToHubPeering 'modules/subscriptions/researcherSubscriptionVnetPeering.bicep' = {
  name: 'researcherToHubPeering'
  scope: subscription(researcherSubscriptionID)
  params: {
    researcherVnetRgName: researcherSubscription.outputs.researcherVnetResourceGroupName
    researcherVnetName: researcherSubscription.outputs.researcherVnetName
    hubVnetName: hubSubscription.outputs.hubVNETName
    hubVnetId: hubSubscription.outputs.hubVNETId
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Resource ID of the Firewall.')
output firewallResourceID string = hubSubscription.outputs.firewallId

@description('Resource ID of the Bastion.')
output bastionResourceID string = virtualDesktopSubscription.outputs.bastionResourceId
@description('Resource ID of the hub virtual network.')
output hubVnetId string = hubSubscription.outputs.hubVNETId

@description('Resource ID of the spoke virtual network.')
output remoteDesktopVnetId string = virtualDesktopSubscription.outputs.rdVnetId

@description('Resource ID of the research virtual network.')
output researchVnetId string = researcherSubscription.outputs.researcherVnetId

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = hubSubscription.outputs.logAnalyticsWorkspaceResourceId
