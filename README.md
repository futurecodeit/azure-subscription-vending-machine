# Azure Subscription Vending Automation

This repository provides a working starter implementation for a governed Azure subscription vending solution. It includes:

- a static catalog request portal for collecting subscription inputs
- a Terraform baseline for subscription creation, management group placement, and foundational configuration
- a Terraform-managed Azure Logic App with an HTTP trigger
- a GitHub Actions workflow that runs Terraform validation and plan
- Key Vault-backed GitHub authentication for the Logic App

## Repository Structure

- `catalog-interface/` – static HTML/CSS/JS portal for request capture and payload generation
- `terraform/` – Terraform configuration for subscription provisioning and governance placement
- `logic-app/terraform/` – Terraform deployment for the Logic App, trigger, actions, and supporting resources
- `.github/workflows/terraform-plan.yml` – GitHub Actions workflow dispatched by the Logic App
- `github-actions/terraform-plan.yml` – source copy of the GitHub Actions workflow

## Catalog Interface

The portal is implemented as a static web app and can be opened directly in a browser.

To run locally:

1. Open the `catalog-interface` directory in a browser, or
2. Serve it locally with:

   python -m http.server 8080

3. Navigate to:

   http://localhost:8080

The form collects the required attributes for subscription requests, including environment, management group, billing profile, networking, RBAC, cost centre, tags, and budget.

## Terraform Provisioning

The Terraform configuration defines a baseline for:

- Azure subscription creation
- management group association
- resource group provisioning
- subscription metadata tagging

Required inputs include:

- tenant_id
- azure_subscription_id
- subscription_name
- subscription_alias
- billing_scope_id
- management_group_id
- project_name
- business_owner
- technical_owner
- cost_centre

Example:

```hcl
terraform init
terraform plan \
  -var="tenant_id=<tenant-id>" \
  -var="azure_subscription_id=<management-subscription-id>" \
  -var="subscription_name=Finance-Data-Platform" \
  -var="subscription_alias=finance-data-platform" \
  -var="billing_scope_id=/providers/Microsoft.Billing/billingAccounts/<id>/billingProfiles/<profile-id>" \
  -var="management_group_id=/providers/Microsoft.Management/managementGroups/landing-zones-nonprod" \
  -var="project_name=Finance Data Platform" \
  -var="business_owner=A. Patel" \
  -var="technical_owner=Cloud Platform Team" \
  -var="cost_centre=CC-4051"
```

## Deployed Azure Resources

The current test deployment uses:

- Subscription: the subscription selected by the authenticated Azure CLI session
- Resource group: `rg-sub-vending`
- Region: `uksouth`
- Logic App: `sub-vending-logicapp`
- Key Vault: `az-kv-lending` in `eastus`
- Key Vault secret: `github-actions-token`
- GitHub repository: `futurecodeit/azure-subscription-vending-machine`
- GitHub workflow: `.github/workflows/terraform-plan.yml` on `main`

The Logic App managed identity reads the GitHub token from Key Vault at runtime. Do not place the token in Git, Terraform variables, workflow YAML, or this README.

## One-Time Setup

### Azure CLI Authentication

Authenticate and confirm the active subscription. The deployment script reads these values automatically; no subscription ID needs to be hardcoded.

```powershell
az login
az account show --query "{subscriptionId:id,tenantId:tenantId,name:name,state:state}" --output table
```

### GitHub Repository

The workflow must be present in the GitHub repository under `.github/workflows/`. GitHub does not execute the copy kept only under `github-actions/`.

```powershell
git add .github/workflows/terraform-plan.yml
git commit -m "Add Terraform plan workflow"
git push origin main
```

Configure these GitHub repository secrets for the `azure/login` step:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

The Entra application represented by `AZURE_CLIENT_ID` also needs a federated credential for:

```text
repo:futurecodeit/azure-subscription-vending-machine:ref:refs/heads/main
```

Use issuer `https://token.actions.githubusercontent.com` and audience `api://AzureADTokenExchange`.

### Key Vault Token

Create or update the Key Vault secret without printing its value in the terminal or committing it:

```powershell
az keyvault secret set --vault-name az-kv-lending --name github-actions-token --value "<replacement-token>"
```

The token must have access to `futurecodeit/azure-subscription-vending-machine` and GitHub Actions `write` permission. If the organization requires approval or SSO authorization, complete that in GitHub before testing.

The Logic App identity must have a Key Vault data-plane role, preferably `Key Vault Secrets User`, scoped to `az-kv-lending`.

## Deploy the Logic App with Terraform

Run these commands from `logic-app/terraform/`. The script obtains the subscription ID and tenant ID from the current Azure CLI context, validates Terraform, creates a plan, and optionally applies it.

```powershell
Set-Location .\logic-app\terraform
.\deploy.ps1 -Apply
```

The actual command should be entered as:

```powershell
.\deploy.ps1 -Apply
```

The deployment creates or updates the Logic App, its HTTP trigger, the Key Vault token retrieval action, and the GitHub dispatch action. It does not create an Azure subscription.

## Configure and Submit the Catalog Request

1. Start the local portal from the repository root:

   ```powershell
   python -m http.server 8080 --directory .
   ```

2. Open `http://localhost:8080/catalog-interface/`.
3. The form is pre-populated with default test values such as `Finance Data Platform`, `Non-Production`, `uksouth`, budget `250000 GBP`, and billing profile `BP-2024-081`.
4. Select **Generate Vending Request** to build and review the payload.
5. Configure the deployed Logic App callback URL in the browser console. Retrieve it from Terraform without committing it:

   ```powershell
   terraform output -raw logic_app_trigger_callback_url
   ```

   ```javascript
   localStorage.setItem('logicAppWorkflowUrl', '<callback-url>');
   ```

6. Select **Send to Logic App**.

The portal payload may omit `managementGroupId`, `billingScopeId`, and `tenantId`. For testing, the Logic App supplies:

- management group test value: `b41b72d0-4e9f-4c26-8a69-f949f367c91d`
- billing scope test value: `/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/00000000`
- tenant ID: the authenticated Azure tenant configured during deployment

These are test values only. Replace the billing scope with a real billing scope before using the workflow for subscription provisioning.

## End-to-End Verification

### 1. Verify the Logic App run

In the Azure portal, open `sub-vending-logicapp` and select **Runs history**. The latest run should contain:

- `Initialize_Request_Status`: `Succeeded`
- `Get_GitHub_Token`: `Succeeded`
- `Trigger_GitHub_Workflow`: `Succeeded` with GitHub response `204 NoContent`
- `Response_Request_Accepted`: `Succeeded`

The Logic App response should contain the submitted request ID and project name.

### 2. Verify the GitHub Actions run

Open the workflow run list:

```text
https://github.com/futurecodeit/azure-subscription-vending-machine/actions
```

The dispatched run should use the `main` branch and contain the catalog request inputs. A successful wiring test means the run is created. A successful Terraform test additionally requires the Azure login and Terraform plan steps to pass.

### 3. Verify from PowerShell

The following checks do not display the GitHub token:

```powershell
$base = "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/rg-sub-vending/providers/Microsoft.Logic/workflows/sub-vending-logicapp"
az rest --method get --url "$base/runs?api-version=2019-05-01" --query "value[0].properties.status" --output tsv
```

Check the GitHub workflow run at:

```text
https://github.com/futurecodeit/azure-subscription-vending-machine/actions/workflows/terraform-plan.yml
```

## Troubleshooting

- `Get_GitHub_Token` fails: check the Key Vault secret name, vault URI, network access, and Logic App identity Key Vault data-plane role.
- `Trigger_GitHub_Workflow` returns `403`: check repository access, GitHub Actions `write` permission, organization approval, and SSO authorization for the token.
- No GitHub run is created: verify the workflow exists on `main` at `.github/workflows/terraform-plan.yml`.
- GitHub `Azure login` fails: check `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, and the Entra federated credential subject.
- Terraform plan fails after Azure login: replace the placeholder billing scope with a real billing scope and verify the management group ID and permissions.

## Logic App Integration Pattern

The logic app workflow should orchestrate the process as follows:

1. Receive request payload from the catalog interface (HTTP trigger)
2. Validate required fields and approvals
3. Check billing profile status and governance rules
4. Invoke a service or workflow to validate management group placement and policy inheritance
5. Call Terraform via Azure DevOps, GitHub Actions, or Azure CLI automation
6. Emit success, rejection, or pending approval notifications

## Recommended Logic App Flow

1. HTTP trigger receives the subscription request JSON.
2. Parse and validate required attributes.
3. Evaluate approval state and required sign-offs.
4. If approved, start a runbook or deployment workflow that executes Terraform.
5. Trigger a Terraform pipeline using Azure DevOps or GitHub Actions.
6. Publish a final status update back to the portal and email stakeholders.

## Azure Implementation Notes

A common implementation pattern is:

- Catalog portal -> Azure Logic App HTTP trigger
- Logic App -> Azure Function / API Management -> approval checks
- Logic App -> Azure DevOps pipeline or GitHub Actions workflow
- Pipeline -> `terraform init` and `terraform apply`
- Terraform -> create subscription, assign management group, and apply base resources

## Security and Governance Controls

This pattern enforces the operating model described in the request:

- no direct unauthorized management group selection
- approval gates before subscription creation
- billing profile validation before provisioning
- policy inheritance after management group placement
- mandatory business and technical tagging
- delegated access via RBAC and approval workflow

