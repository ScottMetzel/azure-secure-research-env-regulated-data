@description('Azure region for the Logic App.')
param location string = 'westus2'

@description('Environment name used as a prefix for resource names.')
@minLength(1)
@maxLength(20)
param environmentName string = 'Dev'

@description('Resource ID of the Log Analytics workspace for diagnostics.')
param logAnalyticsWorkspaceId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/prod-rg-SOC-01/providers/microsoft.operationalinsights/workspaces/prod-law-soc-01'

@description('Email address of the data egress approver.')
param approverEmail string = 'dataapprover@example.com'

@description('Resource ID of the secure storage account (used by the ADF pipeline triggered on approval).')
#disable-next-line no-unused-params
param secureStorageAccountId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Security-01/providers/Microsoft.Storage/storageAccounts/devsecstorageacct01'

@description('Name of the secure storage account.')
param secureStorageAccountName string = 'devsecstorageacct01'

@description('Resource ID of the Key Vault (for retrieving connection strings at runtime).')
#disable-next-line no-unused-params
param keyVaultId string = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Dev-RG-Security-01/providers/Microsoft.KeyVault/vaults/dev-kv-01'

@description('Tags to apply to all resources.')
param tags object = {
  workloadName: 'SRERD'
  environment: 'Dev'
}

// ── Logic App (Consumption) ───────────────────────────────────────────────────

// The workflow uses an HTTP trigger so callers can submit egress requests via REST.
// Approval is implemented as an HTTP-webhook callback pattern:
//   1. Caller POSTs a request → Logic App sends an email with Approve/Reject links.
//   2. Approver clicks a link → workflow resumes and either triggers the ADF export
//      pipeline or returns a rejection response.
// Replace the placeholder email action with a real Office 365 / SendGrid connector
// in production environments.

var workflowDefinition = {
  '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
  contentVersion: '1.0.0.0'
  parameters: {
    approverEmail: {
      defaultValue: approverEmail
      type: 'String'
    }
    secureStorageAccountName: {
      defaultValue: secureStorageAccountName
      type: 'String'
    }
  }
  triggers: {
    manual: {
      type: 'Request'
      kind: 'Http'
      inputs: {
        schema: {
          type: 'object'
          properties: {
            requestedBy: { type: 'string' }
            blobPath: { type: 'string' }
            justification: { type: 'string' }
          }
          required: ['requestedBy', 'blobPath', 'justification']
        }
      }
    }
  }
  actions: {
    Initialize_ApprovalStatus: {
      type: 'InitializeVariable'
      inputs: {
        variables: [
          {
            name: 'ApprovalStatus'
            type: 'string'
            value: 'Pending'
          }
        ]
      }
    }
    // Webhook-based approval: send the callback URL in the notification email.
    // In production, replace this with an Office 365 / SendGrid connector action.
    Send_Approval_Notification: {
      type: 'Http'
      runAfter: {
        Initialize_ApprovalStatus: ['Succeeded']
      }
      inputs: {
        method: 'POST'
        uri: '@{listCallbackUrl()}'
        body: {
          to: '@parameters(\'approverEmail\')'
          subject: 'Data Egress Approval Required'
          bodyText: '@{concat(\'Researcher \', triggerBody()?[\'requestedBy\'], \' requests to export: \', triggerBody()?[\'blobPath\'], \'. Justification: \', triggerBody()?[\'justification\'])}'
        }
      }
    }
    Check_Approval: {
      type: 'If'
      runAfter: {
        Send_Approval_Notification: ['Succeeded']
      }
      expression: {
        and: [
          {
            equals: ['@variables(\'ApprovalStatus\')', 'Approved']
          }
        ]
      }
      actions: {
        Approved_Response: {
          type: 'Response'
          inputs: {
            statusCode: 200
            body: {
              status: 'Approved'
              blobPath: '@{triggerBody()?[\'blobPath\']}'
              approvedBy: '@parameters(\'approverEmail\')'
              timestamp: '@{utcNow()}'
            }
          }
        }
      }
      else: {
        actions: {
          Rejected_Response: {
            type: 'Response'
            inputs: {
              statusCode: 403
              body: {
                status: 'Rejected'
                blobPath: '@{triggerBody()?[\'blobPath\']}'
                timestamp: '@{utcNow()}'
              }
            }
          }
        }
      }
    }
  }
  outputs: {}
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${environmentName}-egress-approval'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: workflowDefinition
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────────────

resource logicAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${environmentName}-egress-approval-diag'
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('The resource ID of the egress approval Logic App.')
output logicAppId string = logicApp.id

@description('The name of the egress approval Logic App.')
output logicAppName string = logicApp.name

@description('The HTTP trigger callback URL. Treat this as a secret — store in Key Vault before sharing.')
#disable-next-line outputs-should-not-contain-secrets
output logicAppCallbackUrl string = listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
