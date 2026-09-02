variable "subscription_id" {
  description = "Azure subscription containing the target resource group."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Existing resource group for the Logic App deployment."
  type        = string
}

variable "logic_app_name" {
  description = "Logic App workflow name."
  type        = string
  default     = "sub-vending-logicapp"
}

variable "storage_account_name" {
  description = "Globally unique, lowercase storage account name."
  type        = string
  default     = "subvendinglogicapp"
}

variable "terraform_runner_url" {
  description = "HTTPS endpoint invoked by a future Terraform runner integration."
  type        = string
  default     = "https://example.com/terraform-runner"
}

variable "github_owner" {
  description = "GitHub repository owner used for workflow dispatch."
  type        = string
  default     = "futurecodeit"
}

variable "github_repository" {
  description = "GitHub repository used for workflow dispatch."
  type        = string
  default     = "azure-subscription-vending-machine"
}

variable "github_ref" {
  description = "Git ref on which the GitHub Actions workflow runs."
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub token used by Logic App to dispatch the workflow. Supply through TF_VAR_github_token."
  type        = string
  sensitive   = true
  default     = ""
}

variable "test_management_group_id" {
  description = "Default management group value used until the portal supplies a real ID."
  type        = string
  default     = "b41b72d0-4e9f-4c26-8a69-f949f367c91d"
}

variable "test_billing_scope_id" {
  description = "Default billing scope value used for plan-only testing."
  type        = string
  default     = "/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/00000000"
}