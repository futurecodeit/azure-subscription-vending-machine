# Azure Subscription Vending Automation

This repository provides a working starter implementation for a governed Azure subscription vending solution. It includes:

- a static catalog request portal for collecting subscription inputs
- a Terraform baseline for subscription creation, management group placement, and foundational configuration
- guidance for integrating the portal with Azure Logic Apps and triggering Terraform provisioning workflows from the governance process

## Repository Structure

- `catalog-interface/` – static HTML/CSS/JS portal for request capture and payload generation
- `terraform/` – Terraform configuration for subscription provisioning and governance placement
- `catalog-interface/*.png` – workflow and reference diagrams for the vending lifecycle

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

## Next Step

Use the catalog form to generate a request payload, then feed that payload into a Logic App workflow that calls the Terraform automation for Azure subscription provisioning.
