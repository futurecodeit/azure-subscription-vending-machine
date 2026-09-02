# Azure Deployment Plan

Status: Draft

## Objective
Convert the existing Logic App Bicep deployment to Terraform and deploy the Logic App stack to Azure.

## Scope
- Terraform resources equivalent to the existing Bicep:
  - Storage account
  - Workflow Standard App Service plan
  - System-assigned-identity Logic App workflow
- Preserve the existing HTTP request trigger and acceptance response.
- Deploy to the existing `rg-sub-vending` resource group in `uksouth`, subject to Azure context confirmation.

## Deployment Path
- IaC: Terraform
- Deployment command: Terraform plan, then Terraform apply after validation
- Authentication: Current authenticated Azure CLI context

## Parameters Requiring Confirmation
- Azure subscription selected by the current CLI session
- Resource group: `rg-sub-vending`
- Location: `uksouth`
- Logic App name: `sub-vending-logicapp`
- Terraform runner URL: currently `https://example.com/terraform-runner` placeholder

## Validation
Pending plan approval and implementation.

## Risks / Notes
- The current Terraform runner URL is a placeholder and will not execute a real downstream GitHub Actions run.
- Creating or modifying Azure resources may incur cost and requires sufficient subscription permissions.
