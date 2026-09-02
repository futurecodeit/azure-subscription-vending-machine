param(
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

$account = az account show --query "{subscriptionId:id,tenantId:tenantId}" --output json | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($account.subscriptionId) -or [string]::IsNullOrWhiteSpace($account.tenantId)) {
  throw "Azure CLI is not authenticated to an active subscription. Run 'az login' first."
}

terraform init -backend=false
terraform validate

$planArguments = @(
  "plan"
  "-var=subscription_id=$($account.subscriptionId)"
  "-var=tenant_id=$($account.tenantId)"
  "-var-file=main.tfvars.json"
  "-out=logic-app.tfplan"
)
terraform @planArguments

if ($Apply) {
  terraform apply logic-app.tfplan
}