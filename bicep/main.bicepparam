// Parameters file for main.bicep
// Replace placeholder values before deploying to a real environment.
// NEVER commit real secrets or passwords to source control.
using './main.bicep'

param location = 'westus2'
param environmentName = 'Dev'
param workloadName = 'SRERD'

// Replace with a strong password or reference an Azure Key Vault secret using
// the syntax: readEnvironmentVariable('ADMIN_PASSWORD') (bicep param files support this)
param adminUsername = 'sreAdmin'
param adminPassword = 'REPLACE_WITH_SECURE_PASSWORD'

// ── Optional overrides ────────────────────────────────────────────────────────
param BastionOrAVD = 'Bastion' // Options: 'Bastion' or 'AVD'
param researcherSubscriptionID = '00000000-0000-0000-0000-000000000000'
param hubSubscriptionID = '00000000-0000-0000-0000-000000000000'
param virtualDesktopSubscriptionID = '00000000-0000-0000-0000-000000000000'

param researcherVMSize = 'Standard_D8s_v5'

param researcherVMCount = 1
param dataApproverEmail = 'data-approver@example.com'
