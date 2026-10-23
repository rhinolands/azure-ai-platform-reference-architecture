# Terraform baseline

A small, tested starting point for the platform subscription. It is not the full architecture in the main README.

## What it creates

- One resource group, `rg-<workload>-<environment>`.
- One Log Analytics workspace for platform telemetry.
- One monthly budget on the resource group. It alerts on actual spend at each threshold (50, 80 and 100 percent by default) and on forecast spend at 100 percent.

Every resource carries the same PascalCase tags: `Environment`, `Workload`, `Owner`, `CostCenter`, `ManagedBy` and `Repository`. Extra tags go in `extra_tags`. Their keys must be PascalCase too, and they cannot override the base tags.

## What it does not create yet

Hub-spoke networking, Private Endpoints, Azure Firewall, API Management, AKS and the model serving layer. Those stay as patterns in the main README for now.

## Versions

- Terraform `~> 1.16.0`.
- `hashicorp/azurerm` pinned to `5.10.0`. The lock file holds hashes for Linux, macOS and Windows.
- No backend block. State is local until you add a remote backend.

## Use

```bash
cp terraform.tfvars.example terraform.tfvars   # set your values
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
terraform plan
```

`terraform test` runs in plan mode against a mocked provider. It needs no Azure login and creates nothing. It checks tag keys and values, resource names, the budget alerts and the input rules.

CI runs fmt, validate, test and a gitleaks scan of the full history on every pull request. It never runs apply.
