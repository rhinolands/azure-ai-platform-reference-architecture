variable "subscription_id" {
  description = "Target Azure subscription id."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  description = "Azure region for every resource in this root."
  type        = string
  default     = "westeurope"
}

variable "workload" {
  description = "Short workload name used in resource names. Lowercase letters and digits."
  type        = string
  default     = "aiplatform"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,15}$", var.workload))
    error_message = "workload must be 3 to 16 lowercase letters or digits, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of dev, test, prod."
  }
}

variable "owner" {
  description = "Owner tag value. A team or person accountable for the resources."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag value."
  type        = string
}

variable "extra_tags" {
  description = "Additional tags. Keys must be PascalCase."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.extra_tags) : can(regex("^[A-Z][A-Za-z0-9]*$", k))])
    error_message = "Every extra_tags key must be PascalCase, for example DataClassification."
  }
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "budget_amount" {
  description = "Monthly budget for the resource group, in the billing currency."
  type        = number

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than zero."
  }
}

variable "budget_start_date" {
  description = "Budget start, the first day of a month in RFC 3339, for example 2026-11-01T00:00:00Z."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be the first day of a month, for example 2026-11-01T00:00:00Z."
  }
}

variable "budget_contact_emails" {
  description = "Addresses that receive budget alerts."
  type        = list(string)

  validation {
    condition     = length(var.budget_contact_emails) > 0 && alltrue([for e in var.budget_contact_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "budget_contact_emails needs at least one valid email address."
  }
}

variable "budget_thresholds" {
  description = "Alert thresholds in percent of budget_amount. Actual spend alerts at each value, forecast alerts at 100."
  type        = list(number)
  default     = [50, 80, 100]

  validation {
    condition     = length(var.budget_thresholds) > 0 && alltrue([for t in var.budget_thresholds : t > 0 && t <= 1000])
    error_message = "budget_thresholds must hold values between 1 and 1000."
  }
}
