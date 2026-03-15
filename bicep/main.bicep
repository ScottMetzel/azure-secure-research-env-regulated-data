targetScope = 'subscription'

// ── Parameters ────────────────────────────────────────────────────────────────

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'sre'

@description('Tags applied to every resource.')
param tags object = {
  environment: 'secure-research'
  managedBy: 'bicep'
}

@description('Local administrator username for VMs.')
param adminUsername string

@description('Local administrator password for VMs.')
@secure()
param adminPassword string

@description('Email address to receive data-egress approval requests.')
param approverEmail string

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VM size for AVD session hosts.')
param vmSize string = 'Standard_D4s_v5'

@description('VM size for Data Science VMs.')
param dsVmSize string = 'Standard_D8s_v5'

@description('Number of AVD session host VMs.')
@minValue(1)
@maxValue(50)
param vmCount int = 2

@description('Number of Data Science VMs.')
@minValue(1)
@maxValue(20)
param dsVmCount int = 1

// ── Resource Groups ───────────────────────────────────────────────────────────

resource networkRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-network-rg'
  location: location
  tags: tags
}

resource computeRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-compute-rg'
  location: location
  tags: tags
}

// ── Monitoring (compute-rg) ───────────────────────────────────────────────────

module monitoring 'modules/monitoring/logAnalytics.bicep' = {
  name: 'monitoring'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

// ── Network (network-rg) ──────────────────────────────────────────────────────

module network 'modules/network/vnet.bicep' = {
  name: 'network'
  scope: networkRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetAddressPrefix: vnetAddressPrefix
  }
}

// ── Key Vault (compute-rg, private endpoint in PrivateEndpointSubnet) ─────────

module keyvault 'modules/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Ingestion Storage (network-rg) ────────────────────────────────────────────

module storageIngestion 'modules/storage/storageIngestion.bicep' = {
  name: 'storageIngestion'
  scope: networkRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Secure Storage (compute-rg, private endpoint in PrivateEndpointSubnet) ────

module storageSecure 'modules/storage/storageSecure.bicep' = {
  name: 'storageSecure'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── Data Factory (network-rg) ─────────────────────────────────────────────────

module datafactory 'modules/datafactory/datafactory.bicep' = {
  name: 'datafactory'
  scope: networkRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.dataIntegrationSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    ingestionStorageAccountId: storageIngestion.outputs.storageAccountId
    ingestionStorageAccountName: storageIngestion.outputs.storageAccountName
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── AVD (compute-rg, NICs in ResearchersSubnet) ───────────────────────────────

module avd 'modules/avd/avd.bicep' = {
  name: 'avd'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.researchersSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    vmSize: vmSize
    vmCount: vmCount
    adminUsername: adminUsername
    adminPassword: adminPassword
    aadJoin: true
  }
}

// ── Data Science VMs (compute-rg, NICs in ComputeSubnet) ─────────────────────

module datasciencevm 'modules/compute/datasciencevm.bicep' = {
  name: 'datasciencevm'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.computeSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    vmSize: dsVmSize
    vmCount: dsVmCount
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// ── Egress Approval Logic App (compute-rg) ────────────────────────────────────

module egressApproval 'modules/logicapp/egressApproval.bicep' = {
  name: 'egressApproval'
  scope: computeRg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    approverEmail: approverEmail
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Name of the network resource group.')
output networkResourceGroupName string = networkRg.name

@description('Name of the compute resource group.')
output computeResourceGroupName string = computeRg.name

@description('Resource ID of the virtual network.')
output vnetId string = network.outputs.vnetId

@description('Resource ID of the Log Analytics workspace.')
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceResourceId

@description('Resource ID of the Key Vault.')
output keyVaultId string = keyvault.outputs.keyVaultId

@description('URI of the Key Vault.')
output keyVaultUri string = keyvault.outputs.keyVaultUri

@description('Name of the ingestion storage account.')
output ingestionStorageAccountName string = storageIngestion.outputs.storageAccountName

@description('Name of the secure storage account.')
output secureStorageAccountName string = storageSecure.outputs.storageAccountName

@description('Name of the Azure Data Factory.')
output dataFactoryName string = datafactory.outputs.dataFactoryName

@description('Name of the AVD host pool.')
output avdHostPoolName string = avd.outputs.hostPoolName

@description('HTTP callback URL for the egress approval Logic App.')
output egressApprovalCallbackUrl string = egressApproval.outputs.logicAppCallbackUrl
