# azure-secure-research-env-regulated-data

An Azure-based Secure Research Environment (SRERD) for regulated data, implemented as a set of modular Azure Bicep templates.

The architecture is an implementation of the reference design published at:
[Design a Secure Research Environment for Regulated Data – Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/secure-compute-for-research).

---

## Architecture Overview

### Resource Group Layout

| Resource Group | Purpose |
|---|---|
| `{env}-monitoring-rg` | Log Analytics workspace (centralised diagnostics for all components) |
| `{env}-hubvnet-rg` | **Hub VNet** — contains `AzureFirewallSubnet`, `AzureBastionSubnet`, `ResearchSubnet` |
| `{env}-firewall-rg` | Azure Firewall (Standard SKU) + Firewall Policy |
| `{env}-bastion-rg` | Azure Bastion (Standard SKU) |
| `{env}-researchvm-rg` | Gen2 D4ds\_v5 Windows Server 2025 Azure Edition research jumpbox VM |
| `{env}-network-rg` | Spoke VNet + Private DNS zones (blob, vault, datafactory, azureml) |
| `{env}-compute-rg` | Key Vault · Secure Storage · Azure Data Factory · Data Science VMs |
| `{env}-ingest-rg` | Publicly-accessible data ingestion storage account |
| `{env}-logicapp-rg` | Data-egress approval Logic App |

### Design Decisions

* **VNet separation**: The hub VNet (Firewall, Bastion, researcher access) lives in its own resource group (`hubvnet-rg`). Azure Firewall, Azure Bastion, and the research VM each have their own resource groups. This follows the principle of least-blast-radius: deleting or locking a component RG doesn't affect the network infrastructure.
* **No public Internet access for VMs**: All research and data-science VMs have no public IP. Researchers connect via Azure Bastion only.
* **Copy-paste disabled on Bastion**: Prevents data exfiltration via clipboard, enforcing the egress approval workflow.
* **Data egress controlled by Logic App**: Any export from the secure storage account requires approval via an HTTP-webhook workflow before Data Factory can move the data out.
* **Immutable secure storage**: The `research-data` blob container has a locked immutability policy, ensuring regulated data cannot be modified or deleted.
* **Hub-spoke VNet peering**: The hub and spoke VNets are bidirectionally peered. The research VM can reach private endpoints in the spoke (storage, Key Vault, ADF) using private DNS zones that are linked to both VNets.

---

## Module Reference

```
bicep/
├── main.bicep               Subscription-scoped orchestrator
├── main.bicepparam          Example parameter values
└── modules/
    ├── monitoring/
    │   └── logAnalytics.bicep          Log Analytics workspace
    ├── network/
    │   ├── hubvnet.bicep               Hub VNet (Firewall + Bastion + Research subnets)
    │   ├── vnet.bicep                  Spoke VNet (Compute + PE + DataIntegration subnets)
    │   ├── vnetPeering.bicep           Single-direction VNet peering (deploy ×2)
    │   ├── dnsZoneLinks.bicep          Add VNet links to existing private DNS zones
    │   ├── firewall.bicep              Azure Firewall + Policy
    ├── bastion/
    │   └── bastion.bicep               Azure Bastion Standard
    ├── compute/
    │   ├── researchvm.bicep            Gen2 D4ds_v5 WS2025 Azure Edition jumpbox VM
    │   └── datasciencevm.bicep         Ubuntu 22.04 DSVM(s)
    ├── keyvault/
    │   └── keyvault.bicep              Key Vault (RBAC, private endpoint, purge protection)
    ├── storage/
    │   ├── storageIngestion.bicep      Publicly-accessible ingestion storage
    │   └── storageSecure.bicep         Private immutable research-data storage
    ├── datafactory/
    │   └── datafactory.bicep           ADF with managed VNet and private endpoint
    ├── logicapp/
    │   └── egressApproval.bicep        HTTP-webhook egress approval Logic App
    └── roleAssignment/
        └── roleAssignment.bicep        RG-scoped RBAC role assignment helper
```

---

## Deployment

### Prerequisites

* Azure CLI ≥ 2.60 with the `bicep` extension, **or** the Bicep CLI ≥ 0.29
* A subscription where you have **Owner** or **User Access Administrator** + **Contributor** rights

### Parameters

Edit `bicep/main.bicepparam` and fill in at minimum:

| Parameter | Description |
|---|---|
| `adminUsername` | Local administrator account name for all VMs |
| `adminPassword` | Strong password (use `readEnvironmentVariable()` in production) |
| `approverEmail` | Email address notified for data-egress approval requests |

Optional overrides (with safe defaults):

| Parameter | Default | Description |
|---|---|---|
| `location` | `eastus` | Azure region |
| `environmentName` | `SRERD` | Prefix for all resource names and RG names |
| `vnetAddressPrefix` | `10.0.0.0/16` | Spoke VNet CIDR |
| `hubVnetAddressPrefix` | `10.1.0.0/16` | Hub VNet CIDR (must not overlap with spoke) |
| `dsVmSize` | `Standard_D8s_v5` | Data Science VM SKU |
| `dsVmCount` | `1` | Number of Data Science VMs |

### Deploy

```bash
az deployment sub create \
  --location eastus \
  --template-file bicep/main.bicep \
  --parameters bicep/main.bicepparam
```

---

## Security Summary

| Control | Implementation |
|---|---|
| No public IPs on research VMs | All NICs have no public IP; access via Bastion only |
| Clipboard exfiltration prevention | `disableCopyPaste: true` on Bastion |
| Internet egress blocked | NSGs deny Internet outbound on all subnets; Firewall default-deny with explicit allow list |
| Private endpoints for all PaaS | Key Vault, Secure Storage, ADF use private endpoints in the spoke VNet |
| Immutable research data | Locked immutability policy on the `research-data` container |
| Key Vault hardening | RBAC mode, purge protection, public network access disabled |
| Data egress approval | Logic App HTTP-webhook workflow; no automated export without explicit approval |
| Trusted Launch on research VM | Secure Boot + vTPM enabled on the Gen2 Windows Server 2025 VM |
| Least-privilege role assignments | ADF granted Storage Blob Data Contributor and KV Secrets User only |
