targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Short environment name used as a prefix for all resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Prod'

@description('Tags applied to every resource.')
param tags object = {
  workloadName: 'SILO'
  environment: environmentName
}

@description('Subscription ID where the research environment will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param researcherSubscriptionID string

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
