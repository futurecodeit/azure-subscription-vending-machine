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
      requestId          = { type = "string" }
      projectName        = { type = "string" }
      environment        = { type = "string" }
      businessUnit       = { type = "string" }
      businessOwner      = { type = "string" }
      technicalOwner     = { type = "string" }
      requestMode        = { type = "string" }
      workloadType       = { type = "string" }
      cybersecurity      = { type = "string" }
      aiUsage            = { type = "string" }
      customerEmail      = { type = "string" }
      validationSummary  = { type = "array" }
      managementGroup    = { type = "string" }
      managementGroupId  = { type = "string" }
      billingProfile     = { type = "string" }
      billingScopeId     = { type = "string" }
      budget             = { type = "number" }
      durationDays       = { type = "integer" }
      terraformOperation = { type = "string" }
      region             = { type = "string" }
      tenantId           = { type = "string" }
      requiredApprovals  = { type = "array" }
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
      requestId          = "@triggerBody()?['requestId']"
      projectName        = "@triggerBody()?['projectName']"
      environment        = "@triggerBody()?['environment']"
      managementGroupId  = "@if(empty(triggerBody()?['managementGroupId']), parameters('testManagementGroupId'), triggerBody()?['managementGroupId'])"
      billingScopeId     = "@if(empty(triggerBody()?['billingScopeId']), parameters('testBillingScopeId'), triggerBody()?['billingScopeId'])"
      region             = "@triggerBody()?['region']"
      tenantId           = "@if(empty(triggerBody()?['tenantId']), parameters('azureTenantId'), triggerBody()?['tenantId'])"
      terraformOperation = "@coalesce(triggerBody()?['terraformOperation'], 'plan')"
      businessUnit       = "@triggerBody()?['businessUnit']"
      businessOwner      = "@triggerBody()?['businessOwner']"
      technicalOwner     = "@triggerBody()?['technicalOwner']"
      costCentre         = "@triggerBody()?['costCentre']"
      budget             = "@triggerBody()?['budget']"
      durationDays       = "@triggerBody()?['durationDays']"
      statusCallbackUrl  = azurerm_logic_app_trigger_http_request.github_status.callback_url
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

resource "azurerm_logic_app_workflow" "notifications" {
  name                = "${var.logic_app_name}-notifications"
  resource_group_name = data.azurerm_resource_group.target.name
  location            = data.azurerm_resource_group.target.location

  identity {
    type = "SystemAssigned"
  }

  enabled = true

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"
}

resource "azurerm_logic_app_trigger_http_request" "github_status" {
  name         = "github-status"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  method       = "POST"
  schema = jsonencode({
    type = "object"
    properties = {
      requestId          = { type = "string" }
      projectName        = { type = "string" }
      environment        = { type = "string" }
      managementGroupId  = { type = "string" }
      billingScopeId     = { type = "string" }
      region             = { type = "string" }
      tenantId           = { type = "string" }
      businessUnit       = { type = "string" }
      businessOwner      = { type = "string" }
      technicalOwner     = { type = "string" }
      costCentre         = { type = "string" }
      budget             = { type = "number" }
      terraformOperation = { type = "string" }
      lifecycleEvent     = { type = "string" }
      durationDays       = { type = "integer" }
      extensionRequested = { type = "boolean" }
      status             = { type = "string" }
      planSummary        = { type = "string" }
      error              = { type = "string" }
      subscriptionId     = { type = "string" }
    }
  })
}

resource "azurerm_role_assignment" "notifications_acs_sender" {
  scope                = var.acs_resource_id
  role_definition_name = "Communication and Email Service Owner"
  principal_id         = azurerm_logic_app_workflow.notifications.identity[0].principal_id
}

resource "azurerm_logic_app_action_custom" "generate_summary_report" {
  name         = "Generate_Summary_Report"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type = "Compose"
    inputs = {
      requestId          = "@triggerBody()?['requestId']"
      projectName        = "@triggerBody()?['projectName']"
      businessUnit       = "@triggerBody()?['businessUnit']"
      businessOwner      = "@triggerBody()?['businessOwner']"
      technicalOwner     = "@triggerBody()?['technicalOwner']"
      status             = "@triggerBody()?['status']"
      lifecycleEvent     = "@triggerBody()?['lifecycleEvent']"
      lifecycleState     = "@variables('lifecycleState')"
      durationDays       = "@triggerBody()?['durationDays']"
      extensionRequested = "@triggerBody()?['extensionRequested']"
      subscriptionId     = "@triggerBody()?['subscriptionId']"
      managementGroup    = "@triggerBody()?['managementGroupId']"
      costCentre         = "@triggerBody()?['costCentre']"
      budget             = "@triggerBody()?['budget']"
      region             = "@triggerBody()?['region']"
      accessInstructions = "Subscription access is managed through approved Azure RBAC assignments."
      guardrails         = "Sandbox guardrails, budget controls, security policies, and monitoring are applied by the provisioning workflow."
      integrations       = "Cloudability, Wiz, and Azure Monitor integration status must be verified after provisioning."
      costMappings       = "Cost centre and budget values are included in the originating request."
      nextLifecycleStep  = "Use the lifecycleEvent callback contract for expiry warnings, extension, grace-period, and closure transitions."
      planSummary        = "@triggerBody()?['planSummary']"
      error              = "@triggerBody()?['error']"
    }
    runAfter = {
      Determine_Lifecycle_State = ["Succeeded"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.determine_lifecycle_state]
}

resource "azurerm_logic_app_action_custom" "initialize_notification_state" {
  name         = "Initialize_Notification_State"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type = "InitializeVariable"
    inputs = {
      variables = [{
        name  = "lifecycleState"
        type  = "string"
        value = "Provisioning"
      }]
    }
    runAfter = {}
  })
}

resource "azurerm_logic_app_action_custom" "determine_lifecycle_state" {
  name         = "Determine_Lifecycle_State"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type       = "Switch"
    expression = "@coalesce(triggerBody()?['lifecycleEvent'], 'terraform-completed')"
    cases = {
      "terraform-completed" = {
        case = "terraform-completed"
        actions = {
          Set_Provisioning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Provisioning complete"
            }
          }
        }
      }
      "subscription-created" = {
        case = "subscription-created"
        actions = {
          Set_Created_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Active"
            }
          }
        }
      }
      "expiry-warning-30d" = {
        case = "expiry-warning-30d"
        actions = {
          Set_30_Day_Warning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Expiry warning: 30 days"
            }
          }
        }
      }
      "expiry-warning-14d" = {
        case = "expiry-warning-14d"
        actions = {
          Set_14_Day_Warning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Expiry warning: 14 days"
            }
          }
        }
      }
      "expiry-warning-7d" = {
        case = "expiry-warning-7d"
        actions = {
          Set_7_Day_Warning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Expiry warning: 7 days"
            }
          }
        }
      }
      "expiry-warning-3d" = {
        case = "expiry-warning-3d"
        actions = {
          Set_3_Day_Warning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Expiry warning: 3 days"
            }
          }
        }
      }
      "expiry-warning-1d" = {
        case = "expiry-warning-1d"
        actions = {
          Set_1_Day_Warning_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Expiry warning: 1 day"
            }
          }
        }
      }
      "extension-requested" = {
        case = "extension-requested"
        actions = {
          Set_Extended_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Extended"
            }
          }
        }
      }
      "grace-period" = {
        case = "grace-period"
        actions = {
          Set_Grace_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Grace period"
            }
          }
        }
      }
      "closure" = {
        case = "closure"
        actions = {
          Set_Closed_State = {
            type = "SetVariable"
            inputs = {
              name  = "lifecycleState"
              value = "Closed"
            }
          }
        }
      }
    }
    default = {
      actions = {
        Set_Default_State = {
          type = "SetVariable"
          inputs = {
            name  = "lifecycleState"
            value = "Provisioning"
          }
        }
      }
    }
    runAfter = {
      Initialize_Notification_State = ["Succeeded"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.initialize_notification_state]
}

resource "azurerm_logic_app_action_custom" "send_customer_email" {
  name         = "Send_Customer_Email"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "${var.acs_endpoint}/emails:send?api-version=2023-03-31"
      headers = {
        "Content-Type" = "application/json"
      }
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://communication.azure.com/"
      }
      body = {
        senderAddress = var.acs_sender_address
        content = {
          subject   = "@concat('Azure subscription ', coalesce(triggerBody()?['lifecycleEvent'], triggerBody()?['operation'], 'notification'), ': ', triggerBody()?['projectName'])"
          plainText = "@string(outputs('Generate_Summary_Report'))"
        }
        recipients = {
          to = [{
            address = var.customer_email
          }]
        }
      }
    }
    runAfter = {
      Generate_Summary_Report = ["Succeeded"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.generate_summary_report, azurerm_role_assignment.notifications_acs_sender]
}

resource "azurerm_logic_app_action_custom" "send_team_email" {
  name         = "Send_Team_Email"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "${var.acs_endpoint}/emails:send?api-version=2023-03-31"
      headers = {
        "Content-Type" = "application/json"
      }
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://communication.azure.com/"
      }
      body = {
        senderAddress = var.acs_sender_address
        content = {
          subject   = "@concat('Azure subscription team notification: ', coalesce(triggerBody()?['lifecycleEvent'], triggerBody()?['operation'], 'notification'), ': ', triggerBody()?['projectName'])"
          plainText = "@string(outputs('Generate_Summary_Report'))"
        }
        recipients = {
          to = [
            { address = var.finops_email },
            { address = var.security_email },
            { address = var.cloud_operations_email },
            { address = var.subscription_owners_email }
          ]
        }
      }
    }
    runAfter = {
      Generate_Summary_Report = ["Succeeded"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.generate_summary_report, azurerm_role_assignment.notifications_acs_sender]
}

resource "azurerm_logic_app_action_custom" "notification_response" {
  name         = "Notification_Response"
  logic_app_id = azurerm_logic_app_workflow.notifications.id
  body = jsonencode({
    type = "Response"
    kind = "Http"
    inputs = {
      statusCode = 202
      body = {
        requestId = "@triggerBody()?['requestId']"
        status    = "@triggerBody()?['status']"
        report    = "@outputs('Generate_Summary_Report')"
      }
    }
    runAfter = {
      Send_Customer_Email = ["Succeeded", "Failed"]
      Send_Team_Email     = ["Succeeded", "Failed"]
    }
  })
  depends_on = [azurerm_logic_app_action_custom.send_customer_email, azurerm_logic_app_action_custom.send_team_email]
}