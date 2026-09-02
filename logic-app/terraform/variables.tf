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

variable "key_vault_uri" {
  description = "Key Vault URI containing the GitHub dispatch token."
  type        = string
  default     = "https://az-kv-lending.vault.azure.net"
}

variable "github_token_secret_name" {
  description = "Key Vault secret name containing the GitHub dispatch token."
  type        = string
  default     = "github-actions-token"
}

variable "test_management_group_id" {
  description = "Default management group value used until the portal supplies a real ID."
  type        = string
  default     = "/providers/Microsoft.Management/managementGroups/lending"
}

variable "test_billing_scope_id" {
  description = "Default billing scope value used for plan-only testing."
  type        = string
  default     = "/providers/Microsoft.Billing/billingAccounts/00000000/billingProfiles/00000000/invoiceSections/00000000"
}

variable "acs_resource_id" {
  description = "Azure Communication Services resource used for lifecycle email notifications."
  type        = string
  default     = "/subscriptions/5e546d2f-02ec-419a-8305-ad234518d98f/resourceGroups/rg-sub-vending/providers/Microsoft.Communication/CommunicationServices/lz"
}

variable "acs_endpoint" {
  description = "Azure Communication Services endpoint."
  type        = string
  default     = "https://lz.india.communication.azure.com"
}

variable "acs_sender_address" {
  description = "Verified ACS Email sender address."
  type        = string
  default     = "DoNotReply@b5fd871c-8f7d-4c19-9ff3-9dfd6e6f6a12.azurecomm.net"
}

variable "customer_email" {
  description = "Default customer notification recipient for testing."
  type        = string
  default     = "srinath_gadalaye@epam.com"
}

variable "finops_email" {
  description = "FinOps notification recipient."
  type        = string
  default     = "srinath_gadalaye@epam.com"
}

variable "security_email" {
  description = "Security notification recipient."
  type        = string
  default     = "srinath_gadalaye@epam.com"
}

variable "cloud_operations_email" {
  description = "Cloud Operations notification recipient."
  type        = string
  default     = "srinath_gadalaye@epam.com"
}

variable "subscription_owners_email" {
  description = "Subscription owners notification recipient."
  type        = string
  default     = "srinath_gadalaye@epam.com"
}