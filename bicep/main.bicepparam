// Parameters file for main.bicep
// Replace placeholder values before deploying to a real environment.
// NEVER commit real secrets or passwords to source control.
using './main.bicep'

// ── Required parameters ───────────────────────────────────────────────────────

param adminUsername = 'sreAdmin'

// Replace with a strong password or reference an Azure Key Vault secret using
// the syntax: readEnvironmentVariable('ADMIN_PASSWORD') (bicep param files support this)
param adminPassword = 'REPLACE_WITH_SECURE_PASSWORD'

param approverEmail = 'data-approver@example.com'

// ── Optional overrides ────────────────────────────────────────────────────────

param location = 'eastus'

param environmentName = 'sre'

param tags = {
  environment: 'secure-research'
  managedBy: 'bicep'
  costCenter: 'research-it'
}

// Spoke VNet address space
param vnetAddressPrefix = '10.0.0.0/16'

// Hub VNet address space (must not overlap with spoke)
param hubVnetAddressPrefix = '10.1.0.0/16'

param dsVmSize = 'Standard_D8s_v5'

param dsVmCount = 1
