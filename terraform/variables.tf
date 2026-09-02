variable "tenant_id" {
  description = "Azure tenant ID used for the subscription vending process."
  type        = string
}

variable "azure_subscription_id" {
  description = "The Azure subscription ID used by the Terraform provider for the management account."
  type        = string
}

variable "subscription_name" {
  description = "Display name of the Azure subscription to be created."
  type        = string
}

variable "subscription_alias" {
  description = "Alias name used for the subscription request."
  type        = string
}

variable "billing_scope_id" {
  description = "The Azure billing scope ID (billing account / billing profile) to associate the new subscription."
  type        = string
}

variable "workload" {
  description = "Subscription workload type. Use Production or DevTest."
  type        = string
  default     = "Production"

  validation {
    condition     = contains(["Production", "DevTest"], var.workload)
    error_message = "The workload must be either Production or DevTest."
  }
}

variable "management_group_id" {
  description = "Management group resource ID where the subscription should be placed."
  type        = string
}

variable "environment" {
  description = "Environment classification for the requested subscription."
  type        = string
  default     = "Non-Production"
}

variable "project_name" {
  description = "Business application or project name associated with the subscription."
  type        = string
}

variable "business_owner" {
  description = "Business owner for the subscription."
  type        = string
}

variable "technical_owner" {
  description = "Technical owner responsible for the subscription and workloads."
  type        = string
}

variable "cost_centre" {
  description = "Financial cost centre for subscription chargeback."
  type        = string
}

variable "data_classification" {
  description = "Required data classification (internal, confidential, highly confidential)."
  type        = string
  default     = "Confidential"
}

variable "location" {
  description = "Default Azure region for foundation resources."
  type        = string
  default     = "uksouth"
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics workspace resource ID for platform diagnostics. Leave empty if diagnostics are not configured."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the Azure subscription after creation."
  type        = map(string)
  default     = {}
}
