locals {
  name_suffix = "${var.workload}-${var.environment}"

  # Tag keys are PascalCase. Base tags win over extra_tags.
  tags = merge(var.extra_tags, {
    Environment = var.environment
    Workload    = var.workload
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Repository  = "rhinolands/azure-ai-platform-reference-architecture"
  })
}
