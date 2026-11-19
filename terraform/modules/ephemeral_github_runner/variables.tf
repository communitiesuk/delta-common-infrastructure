variable "github_app_id" {
  description = "Numeric ID of the GitHub App installed on communitiesuk/delta-marklogic-deploy."
  type        = string
  default     = "5783568"

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_app_id))
    error_message = "Provide the numeric GitHub App ID, not the client ID or installation ID."
  }
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["test", "staging", "production"], var.environment)
    error_message = "Environment must be test, staging, or production."
  }
}

variable "artifact_directory" {
  type = string
}

variable "logging_retention_in_days" {
  type = number
}
