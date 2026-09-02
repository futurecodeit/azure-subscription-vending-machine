resource "azurerm_subscription" "this" {
  subscription_name = var.subscription_name
  billing_scope_id = var.billing_scope_id
  tags = merge(
    {
      "environment"        = var.environment
      "project-name"       = var.project_name
      "business-owner"     = var.business_owner
      "technical-owner"    = var.technical_owner
      "cost-centre"        = var.cost_centre
      "data-classification" = var.data_classification
      "managed-by"         = "azure-subscription-vending"
    },
    var.tags
  )
}

resource "azurerm_management_group_subscription_association" "this" {
  management_group_id = var.management_group_id
  subscription_id     = azurerm_subscription.this.subscription_id
}

resource "azurerm_resource_group" "foundation" {
  name     = "rg-platform-foundation"
  location = var.location

  tags = merge(
    {
      "environment"        = var.environment
      "project-name"       = var.project_name
      "business-owner"     = var.business_owner
      "technical-owner"    = var.technical_owner
      "cost-centre"        = var.cost_centre
      "data-classification" = var.data_classification
    },
    var.tags
  )
}

resource "azurerm_monitor_diagnostic_setting" "resource_group_logs" {
  count                      = var.log_analytics_workspace_id == null ? 0 : 1
  name                       = "diag-${azurerm_resource_group.foundation.name}"
  target_resource_id         = azurerm_resource_group.foundation.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
