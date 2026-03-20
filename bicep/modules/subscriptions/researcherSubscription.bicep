targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Address prefix for the virtual network.')
param vnetAddressPrefix string = '10.100.60.0/21'

param webSubnetPrefix string = '10.100.60.64/27'
param appSubnetPrefix string = '10.100.60.96/27'
param dbSubnetPrefix string = '10.100.60.128/27'

@description('Address prefix for the storage subnet, used with Azure Storage Accounts and FSLogix.')
param storageSubnetPrefix string = '10.100.60.160/27'

param webVNETIntegrationSubnetPrefix string = '10.100.60.192/27'

@description('Address prefix for the first Data Science Server subnet.')
param researcherServerSubnetPrefix string = '10.100.61.0/28'

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SILO'
  environment: environmentName
}

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Data owner/approver resource group — contains the publicly-accessible data ingestion storage account, Logic App, and Fabric Data Factory resources.')
resource dataOwnerApproverRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-DataOwnerApprover-01'
  location: location
  tags: tags
}

@description('Researcher resource group — contains the resources which researchers will be primarily working with.')
resource researcherRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-Researcher-01'
  location: location
  tags: tags
}

@description('Spoke VNET resource group — contains the spoke Virtual Network (including Researcher VM subnet, and subnets for resources with Private Endpoints which researchers will access).')
resource spokeVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-NetworkInfrastructure-01'
  location: location
  tags: tags
}

// ── Resources via Modules ───────────────────────────────────────────────────────────
module researcherNetworking '../network/networking_researcher.bicep' = {
  name: 'researcherNetworking'
  scope: spokeVNETRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vnetAddressPrefix: vnetAddressPrefix
    webSubnetPrefix: webSubnetPrefix
    appSubnetPrefix: appSubnetPrefix
    dbSubnetPrefix: dbSubnetPrefix
    storageSubnetPrefix: storageSubnetPrefix
    webVNETIntegrationSubnetPrefix: webVNETIntegrationSubnetPrefix
    researcherServerSubnetPrefix: researcherServerSubnetPrefix
  }
}

// ── Key Vault (compute-rg, private endpoint in PrivateEndpointSubnet) ─────────

module keyvault '../keyvault/keyvault.bicep' = {
  name: 'keyvault'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Ingestion Storage (ingest-rg) ─────────────────────────────────────────────
// Publicly-accessible storage for external data uploads.
// Requirement: Public storage account in its own resource group.

module storageIngestion '../storage/storageIngestion.bicep' = {
  name: 'storageIngestion'
  scope: dataOwnerApproverRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
  }
}

// ── Secure Storage (compute-rg, private endpoint in PrivateEndpointSubnet) ────

module storageSecure '../storage/storageSecure.bicep' = {
  name: 'storageSecure'
  scope: researcherRG
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

// ── Data Factory (compute-rg, private endpoint in DataIntegrationSubnet) ──────

module datafactory '../datafactory/datafactory.bicep' = {
  name: 'datafactory'
  scope: researcherRG
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    subnetId: network.outputs.dataIntegrationSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceResourceId
    secureStorageAccountId: storageSecure.outputs.storageAccountId
    secureStorageAccountName: storageSecure.outputs.storageAccountName
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

// ── ADF → Ingestion Storage Role Assignment (ingest-rg) ──────────────────────
// The ingestion storage account lives in ingest-rg while ADF lives in compute-rg.
// The role assignment must be deployed in ingest-rg to avoid a cross-RG scope error.

module adfIngestionRoleAssignment '../roleAssignment/roleAssignment.bicep' = {
  name: 'adfIngestionRoleAssignment'
  scope: dataOwnerApproverRG
  params: {
    principalId: datafactory.outputs.dataFactoryPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    seed: '${storageIngestion.outputs.storageAccountId}-adf-sbc'
  }
}

// ── Data Science VMs (compute-rg, NICs in ComputeSubnet) ─────────────────────

module datasciencevm '../compute/datasciencevm.bicep' = {
  name: 'datasciencevm'
  scope: researcherRG
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

// ── Egress Approval Logic App (logicapp-rg) ───────────────────────────────────
// Requirement: Logic App in its own resource group.

module egressApproval '../logicapp/egressApproval.bicep' = {
  name: 'egressApproval'
  scope: dataOwnerApproverRG
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

// ── Outputs ───────────────────────────────────────────────────────────
@description('The name of the Researcher VNET Resource Group.')
output researcherVnetResourceGroupName string = spokeVNETRG.name

@description('Researcher VNET ID.')
output researcherVnetId string = researcherNetworking.outputs.vnetId

@description('Researcher VNET Name.')
output researcherVnetName string = researcherNetworking.outputs.vnetName

@description('Researcher NSG ID.')
output researcherNsgId string = researcherNetworking.outputs.nsgId
