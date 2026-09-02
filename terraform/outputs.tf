output "subscription_name" {
  description = "Created Azure subscription display name."
  value       = azurerm_subscription.this.subscription_name
}

output "subscription_id" {
  description = "Created Azure subscription resource ID."
  value       = azurerm_subscription.this.subscription_id
}

output "management_group_association_id" {
  description = "Management group association resource ID for the new subscription."
  value       = azurerm_management_group_subscription_association.this.id
}

output "foundation_resource_group_name" {
  description = "Foundation resource group created as part of the vending process."
  value       = azurerm_resource_group.foundation.name
}

output "foundation_resource_group_id" {
  description = "Foundation resource group resource ID."
  value       = azurerm_resource_group.foundation.id
}
