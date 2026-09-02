output "logic_app_name" {
  value = azurerm_logic_app_workflow.vending.name
}

output "logic_app_resource_id" {
  value = azurerm_logic_app_workflow.vending.id
}

output "logic_app_identity_principal_id" {
  value = azurerm_logic_app_workflow.vending.identity[0].principal_id
}

output "logic_app_trigger_callback_url" {
  value     = azurerm_logic_app_trigger_http_request.manual.callback_url
  sensitive = true
}

output "storage_account_name" {
  value = azurerm_storage_account.workflow.name
}

output "service_plan_name" {
  value = azurerm_service_plan.workflow.name
}