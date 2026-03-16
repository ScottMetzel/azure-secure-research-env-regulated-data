// roleAssignment.bicep
// Creates a single Azure RBAC role assignment on a resource in this resource group.
// Deploy one instance per role assignment, scoped to the target resource's resource group.

@description('The principal ID (object ID) to assign the role to.')
param principalId string

@description('The built-in role definition ID (GUID only, without subscription path).')
param roleDefinitionId string

@description('Type of the principal: ServicePrincipal, User, or Group.')
@allowed(['ServicePrincipal', 'User', 'Group'])
param principalType string = 'ServicePrincipal'

@description('A stable seed string used to generate a deterministic role assignment GUID.')
param seed string

// ── Role Assignment ───────────────────────────────────────────────────────────

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(seed, principalId, roleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the role assignment.')
output roleAssignmentId string = roleAssignment.id
