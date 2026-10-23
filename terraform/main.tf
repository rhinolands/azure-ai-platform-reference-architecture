resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "log-${local.name_suffix}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

resource "azurerm_consumption_budget_resource_group" "platform" {
  name              = "budget-${local.name_suffix}"
  resource_group_id = azurerm_resource_group.platform.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      enabled        = true
      operator       = "GreaterThanOrEqualTo"
      threshold      = notification.value
      threshold_type = "Actual"
      contact_emails = var.budget_contact_emails
    }
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }
}
