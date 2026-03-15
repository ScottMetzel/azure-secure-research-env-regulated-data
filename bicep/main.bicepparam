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

param vnetAddressPrefix = '10.0.0.0/16'

param vmSize = 'Standard_D4s_v5'

param dsVmSize = 'Standard_D8s_v5'

param vmCount = 2

param dsVmCount = 1
