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

@description('Subscription ID where the hub VNet (with Firewall) will be deployed. Used for cross-subscription resource deployments and role assignments.')
@minLength(36)
@maxLength(36)
param hubSubscriptionID string

// ── Resource Groups ───────────────────────────────────────────────────────────
@description('Hub VNET resource group — contains the hub Virtual Network and Firewall.')
resource hubVNETRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${environmentName}-RG-NetworkInfrastructure-01'
  location: location
  tags: tags
}
