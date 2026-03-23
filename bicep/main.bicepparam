// Parameters file for main.bicep
// Replace placeholder values before deploying to a real environment.
// NEVER commit real secrets or passwords to source control.
using './main.bicep'

// ── Required parameters ───────────────────────────────────────────────────────
param adminUsername = 'sreAdmin'

// Replace with a strong password or reference an Azure Key Vault secret using
// the syntax: readEnvironmentVariable('ADMIN_PASSWORD') (bicep param files support this)
param adminPassword = 'REPLACE_WITH_SECURE_PASSWORD'
param dataApproverEmail = 'data-approver@example.com'

param researcherSubscriptionID = '00000000-0000-0000-0000-000000000000'
param hubSubscriptionID = '00000000-0000-0000-0000-000000000000'
param virtualDesktopSubscriptionID = '00000000-0000-0000-0000-000000000000'

// ── Optional overrides ────────────────────────────────────────────────────────

param location = 'eastus'

param environmentName = 'sre'

param tags = {
  environment: 'secure-research'
  managedBy: 'bicep'
  costCenter: 'research-it'
}

param researcherVMSize = 'Standard_D8s_v5'

param researcherVMCount = 1
