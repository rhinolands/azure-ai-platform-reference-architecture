output "resource_group_name" {
  description = "Name of the platform resource group."
  value       = azurerm_resource_group.platform.name
}

output "log_analytics_workspace_id" {
  description = "Resource id of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.platform.id
}

output "budget_id" {
  description = "Resource id of the resource group budget."
  value       = azurerm_consumption_budget_resource_group.platform.id
}

output "tags" {
  description = "Tags applied to every resource."
  value       = local.tags
}
