# Plan-mode tests. The provider is mocked, so no Azure login and no apply.

mock_provider "azurerm" {}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  environment           = "dev"
  owner                 = "platform-team"
  cost_center           = "cc-0000"
  budget_amount         = 200
  budget_start_date     = "2026-11-01T00:00:00Z"
  budget_contact_emails = ["alerts@example.com"]
}

run "tags_are_pascal_case_and_complete" {
  command = plan

  variables {
    extra_tags = { DataClassification = "Internal" }
  }

  assert {
    condition     = alltrue([for k in keys(azurerm_resource_group.platform.tags) : can(regex("^[A-Z][A-Za-z0-9]*$", k))])
    error_message = "Every tag key must be PascalCase."
  }

  assert {
    condition = alltrue([
      for k in ["Environment", "Workload", "Owner", "CostCenter", "ManagedBy", "Repository", "DataClassification"] :
      contains(keys(azurerm_resource_group.platform.tags), k)
    ])
    error_message = "Required tags are missing from the resource group."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.platform.tags == azurerm_resource_group.platform.tags
    error_message = "The workspace must carry the same tags as the resource group."
  }

  assert {
    condition     = azurerm_resource_group.platform.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy must be Terraform."
  }
}

run "base_tags_override_extra_tags" {
  command = plan

  variables {
    extra_tags = { Environment = "prod" }
  }

  assert {
    condition     = azurerm_resource_group.platform.tags["Environment"] == "dev"
    error_message = "extra_tags must not override the Environment tag."
  }
}

run "names_follow_convention" {
  command = plan

  assert {
    condition     = azurerm_resource_group.platform.name == "rg-aiplatform-dev"
    error_message = "Unexpected resource group name."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.platform.name == "log-aiplatform-dev"
    error_message = "Unexpected workspace name."
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.platform.name == "budget-aiplatform-dev"
    error_message = "Unexpected budget name."
  }
}

run "budget_alerts_on_actual_and_forecast" {
  command = plan

  assert {
    condition     = azurerm_consumption_budget_resource_group.platform.amount == 200
    error_message = "Budget amount does not match the input."
  }

  assert {
    condition     = azurerm_consumption_budget_resource_group.platform.time_grain == "Monthly"
    error_message = "Budget must reset monthly."
  }

  assert {
    condition     = length([for n in azurerm_consumption_budget_resource_group.platform.notification : n if n.threshold_type == "Actual"]) == 3
    error_message = "Expected one actual-spend alert per default threshold (50, 80, 100)."
  }

  assert {
    condition     = length([for n in azurerm_consumption_budget_resource_group.platform.notification : n if n.threshold_type == "Forecasted" && n.threshold == 100]) == 1
    error_message = "Expected one forecast alert at 100 percent."
  }

  assert {
    condition     = alltrue([for n in azurerm_consumption_budget_resource_group.platform.notification : n.enabled && tolist(n.contact_emails) == tolist(["alerts@example.com"])])
    error_message = "Every budget alert must be enabled and go to the contact list."
  }
}

run "rejects_camel_case_tag_key" {
  command = plan

  variables {
    extra_tags = { dataClassification = "Internal" }
  }

  expect_failures = [var.extra_tags]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_empty_budget_contacts" {
  command = plan

  variables {
    budget_contact_emails = []
  }

  expect_failures = [var.budget_contact_emails]
}

run "rejects_zero_budget" {
  command = plan

  variables {
    budget_amount = 0
  }

  expect_failures = [var.budget_amount]
}

run "rejects_mid_month_budget_start" {
  command = plan

  variables {
    budget_start_date = "2026-11-15T00:00:00Z"
  }

  expect_failures = [var.budget_start_date]
}
