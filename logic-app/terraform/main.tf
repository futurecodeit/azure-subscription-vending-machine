terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "~> 1.2"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id     = var.subscription_id
  tenant_id           = var.tenant_id
  storage_use_azuread = true
}

provider "azurecaf" {}

data "azurerm_resource_group" "target" {
  name = var.resource_group_name
}

resource "azurerm_storage_account" "workflow" {
  name                            = var.storage_account_name
  resource_group_name             = data.azurerm_resource_group.target.name
  location                        = data.azurerm_resource_group.target.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = true
  shared_access_key_enabled       = false
  local_user_enabled              = false
  allow_nested_items_to_be_public = false
}

resource "azurerm_service_plan" "workflow" {
  name                = "${var.logic_app_name}-plan"
  resource_group_name = data.azurerm_resource_group.target.name
  location            = data.azurerm_resource_group.target.location
  os_type             = "Windows"
  sku_name            = "WS1"
}

resource "azurerm_logic_app_workflow" "vending" {
  name                = var.logic_app_name
  resource_group_name = data.azurerm_resource_group.target.name
  location            = data.azurerm_resource_group.target.location

  identity {
    type = "SystemAssigned"
  }

  enabled = true

  parameters = {
    terraformRunnerUrl    = var.terraform_runner_url
    testManagementGroupId = var.test_management_group_id
    testBillingScopeId    = var.test_billing_scope_id
    azureTenantId         = var.tenant_id
  }

  workflow_parameters = {
    terraformRunnerUrl = jsonencode({
      defaultValue = var.terraform_runner_url
      type         = "String"
    })
    testManagementGroupId = jsonencode({
      defaultValue = var.test_management_group_id
      type         = "String"
    })
    testBillingScopeId = jsonencode({
      defaultValue = var.test_billing_scope_id
      type         = "String"
    })
    azureTenantId = jsonencode({
      defaultValue = var.tenant_id
      type         = "String"
    })
  }

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"
}

resource "azurerm_logic_app_trigger_http_request" "manual" {
  name         = "manual"
  logic_app_id = azurerm_logic_app_workflow.vending.id
  method       = "POST"
  schema = jsonencode({
    type = "object"
    properties = {
      requestId         = { type = "string" }
      projectName       = { type = "string" }
      environment       = { type = "string" }
      managementGroup   = { type = "string" }
      managementGroupId = { type = "string" }
      billingProfile    = { type = "string" }
      billingScopeId    = { type = "string" }
      budget            = { type = "number" }
      region            = { type = "string" }
      tenantId          = { type = "string" }
      requiredApprovals = { type = "array" }
    }
  })
}

resource "azurerm_logic_app_action_custom" "initialize_request_status" {
  name         = "Initialize_Request_Status"
  logic_app_id = azurerm_logic_app_workflow.vending.id
  body = jsonencode({
    type = "InitializeVariable"
    inputs = {
      variables = [{
        name  = "requestStatus"
        type  = "string"
        value = "Received"
      }]
    }
    runAfter = {}
  })
}

resource "azurerm_logic_app_action_custom" "response_request_accepted" {
  name         = "Response_Request_Accepted"
  logic_app_id = azurerm_logic_app_workflow.vending.id
  body = jsonencode({
    type = "Response"
    kind = "Http"
    inputs = {
      statusCode = 200
      body = {
        message     = "Subscription vending request accepted."
        requestId   = "@triggerBody()?['requestId']"
        projectName = "@triggerBody()?['projectName']"
        status      = "@variables('requestStatus')"
      }
    }
    runAfter = {
      Trigger_GitHub_Workflow = ["Succeeded", "Failed"]
    }
  })
  depends_on = [azurerm_logic_app_action_http.github_dispatch]
}

resource "azurerm_logic_app_action_http" "github_dispatch" {
  name         = "Trigger_GitHub_Workflow"
  logic_app_id = azurerm_logic_app_workflow.vending.id
  method       = "POST"
  uri          = "https://api.github.com/repos/${var.github_owner}/${var.github_repository}/actions/workflows/terraform-plan.yml/dispatches"
  headers = {
    Accept                 = "application/vnd.github+json"
    Authorization          = "Bearer @{body('Get_GitHub_Token')?['value']}"
    "X-GitHub-Api-Version" = "2022-11-28"
    "Content-Type"         = "application/json"
  }
  body = jsonencode({
    ref = var.github_ref
    inputs = {
      requestId         = "@triggerBody()?['requestId']"
      projectName       = "@triggerBody()?['projectName']"
      environment       = "@triggerBody()?['environment']"
      managementGroupId = "@if(empty(triggerBody()?['managementGroupId']), parameters('testManagementGroupId'), triggerBody()?['managementGroupId'])"
      billingScopeId    = "@if(empty(triggerBody()?['billingScopeId']), parameters('testBillingScopeId'), triggerBody()?['billingScopeId'])"
      region            = "@triggerBody()?['region']"
      tenantId          = "@if(empty(triggerBody()?['tenantId']), parameters('azureTenantId'), triggerBody()?['tenantId'])"
    }
  })
  run_after {
    action_name   = azurerm_logic_app_action_custom.get_github_token.name
    action_result = "Succeeded"
  }
}

resource "azurerm_logic_app_action_custom" "get_github_token" {
  name         = "Get_GitHub_Token"
  logic_app_id = azurerm_logic_app_workflow.vending.id
  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "${var.key_vault_uri}/secrets/${var.github_token_secret_name}?api-version=7.4"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://vault.azure.net"
      }
    }
    runAfter = {
      Initialize_Request_Status = ["Succeeded"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.initialize_request_status]
}