targetScope = 'subscription'

@description('Subscription ID where the Bastion and virtual desktop environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param virtualDesktopSubscriptionID string

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

param spokeVNETAddressPrefix string = ''
param bastionSubnetPrefix string = ''
param rdServerSubnetPrefix string = ''
param avdSubnetPrefix string = ''
param storageSubnetPrefix string = ''

@description('Local administrator username for VMs.')
param adminUsername string

@description('Local administrator password for VMs.')
@secure()
param adminPassword string

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SILO'
  environment: environmentName
}

// ── Resource Groups ───────────────────────────────────────────────────────────

@description('Spoke VNET resource group — contains the spoke Virtual Network (including Bastion subnet, Remote Desktop Server VM subnet, and AVD subnet for future AVD deployment)')
resource spokeVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-NetworkInfrastructure-01'
  location: location
  tags: tags
}

@description('Bastion resource group — contains Azure Bastion and its public IP.')
resource bastionRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Bastion-01'
  location: location
  tags: tags
}

@description('Remote Desktop Server VM resource group — contains the Remote Desktop Server VMs.')
resource rdServerVMRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-RDServerVM-01'
  location: location
  tags: tags
}

// ── Resources ───────────────────────────────────────────────────────────
module network '../network/virtualDesktopNetworking.bicep' = {
  name: 'virtualDesktopNetworking'
  scope: spokeVNETRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetAddressPrefix: spokeVNETAddressPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    rdServerSubnetPrefix: rdServerSubnetPrefix
    avdSubnetPrefix: avdSubnetPrefix
    storageSubnetPrefix: storageSubnetPrefix
  }
}
