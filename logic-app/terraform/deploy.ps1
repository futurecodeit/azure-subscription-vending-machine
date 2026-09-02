param(
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

$account = az account show --query "{subscriptionId:id,tenantId:tenantId}" --output json | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($account.subscriptionId) -or [string]::IsNullOrWhiteSpace($account.tenantId)) {
  throw "Azure CLI is not authenticated to an active subscription. Run 'az login' first."
}

if ($Apply -and [string]::IsNullOrWhiteSpace($env:TF_VAR_github_token)) {
  throw "TF_VAR_github_token is required for an applied GitHub workflow dispatch. Set it in this terminal without committing it, then rerun with -Apply."
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