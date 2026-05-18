# Initial Azure Setup

This guide covers the one-time GitHub Actions OIDC bootstrap performed by [initial-azure-setup.sh](initial-azure-setup.sh). The script creates the Azure managed identity and federation needed for GitHub Actions to deploy this repository without storing client secrets.

## What the script does

`initial-azure-setup.sh` can:

- Create a user-assigned managed identity for the repo
- Create or update the GitHub OIDC federated credential for an environment
- Add the managed identity to the Landing Zone contributor security group
- Create a storage account and container for Terraform state
- Assign storage and Key Vault RBAC needed by the deployment flow
- Optionally create GitHub environment secrets and variables with `gh`

## Prerequisites

You need the following before running the script:

| Requirement | Notes |
|---|---|
| Azure CLI | Required. Run `az login` first and complete the browser MFA prompt. |
| Terraform | Required because the script checks for it before proceeding. |
| GitHub CLI (`gh`) | Optional unless you use `--create-github-secrets`. |
| Azure access | Access to the target subscription and resource group. |
| Entra group ownership | For automatic security-group membership, you must be an owner of `DO_PuC_Azure_Live_<license-plate>_Contributor` or the group passed with `--security-group`. |
| GitHub repo admin access | Required only when using `--create-github-secrets`. |

If you are not an owner of the deployment security group, the script still creates the managed identity and OIDC federation, but a project lead must manually add the identity to the correct Entra security group afterward.

## Required inputs

| Option | Meaning |
|---|---|
| `-g`, `--resource-group` | Landing Zone networking resource group |
| `-n`, `--identity-name` | User-assigned managed identity name |
| `-r`, `--github-repo` | GitHub repo in `owner/repository` format |
| `-e`, `--environment` | GitHub environment name such as `dev`, `test`, `prod`, or `tools` |

## Optional inputs

| Option | Meaning |
|---|---|
| `-s`, `--subscription-id` | Subscription to target. If omitted, the current Azure CLI context is used. |
| `-sg`, `--security-group` | Explicit Entra security group for contributor access |
| `--contributor-scope` | Reserved scope input exposed by the script |
| `--storage-account` | Override the generated Terraform state storage account name |
| `--storage-container` | Override the storage container name. Default: `tfstate` |
| `--create-storage` | Create Terraform state storage |
| `--create-github-secrets` | Create GitHub environment secrets and variables with `gh` |
| `--dry-run` | Print actions without changing Azure or GitHub |
| `-h`, `--help` | Show script help |

## Quick start

Run the script from the repository root.

Preview the changes first:

```bash
bash ./initial-azure-setup.sh \
  -g "<landing-zone-networking-rg>" \
  -n "<managed-identity-name>" \
  -r "<repo-owner>/<repo-name>" \
  -e "<environment>" \
  -s "<subscription-id>" \
  --create-storage \
  --dry-run
```

Create the identity, federation, and Terraform state storage:

```bash
bash ./initial-azure-setup.sh \
  -g "<landing-zone-networking-rg>" \
  -n "<managed-identity-name>" \
  -r "<repo-owner>/<repo-name>" \
  -e "<environment>" \
  -s "<subscription-id>" \
  --create-storage
```

Create the GitHub environment secrets and variables as well:

```bash
bash ./initial-azure-setup.sh \
  -g "<landing-zone-networking-rg>" \
  -n "<managed-identity-name>" \
  -r "<repo-owner>/<repo-name>" \
  -e "<environment>" \
  -s "<subscription-id>" \
  --security-group "DO_PuC_Azure_Live_<license-plate>_Contributor" \
  --create-storage \
  --create-github-secrets
```

Example for this repository:

```bash
bash ./initial-azure-setup.sh \
  -g "<landing-zone-networking-rg>" \
  -n "eo-dmi-alz-bastion-jumpbox-<environment>-identity" \
  -r "bcgov/eo-dmi-alz-bastion-jumpbox" \
  -e "<environment>" \
  -s "<subscription-id>" \
  --create-storage
```

## Naming behavior

The script derives several values automatically:

- Default security group: `DO_PuC_Azure_Live_<license-plate>_Contributor`, where `<license-plate>` is the prefix before the first `-` in the resource group name
- Default storage account name: `tf<environment><repo>`, lowercased, stripped to alphanumerics, and truncated to Azure storage naming limits
- Federated credential subject: `repo:<owner>/<repo>:environment:<environment>`
- GitHub repo variable `SUBSCRIPTION_NAME`: derived from the Azure subscription display name

## What gets written to GitHub

When `--create-github-secrets` is used, the script manages:

- Environment secrets: `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, `VNET_NAME`, `VNET_RESOURCE_GROUP_NAME`
- Repo variable: `SUBSCRIPTION_NAME`
- Environment variable: `STORAGE_ACCOUNT_NAME`
- Repo secret `SOURCE_VNET_ADDRESS_SPACE` when the target environment is `tools`

## After the script finishes

Verify the following before running the GitHub Actions deployment workflow:

1. The managed identity exists in the target resource group.
2. The federated credential exists for the target GitHub environment.
3. The managed identity is a member of the correct Entra contributor group, either automatically or via manual follow-up.
4. The Terraform state storage account and container exist if `--create-storage` was used.
5. The GitHub environment secrets and variables are present if `--create-github-secrets` was used.

If you need the overall Bastion and jumpbox deployment flow after this bootstrap step, return to [README.md](README.md).