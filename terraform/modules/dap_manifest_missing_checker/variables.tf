variable "environment" {
  description = "test, staging or production"
  type        = string
}

variable "dap_manifest_missing_emails" {
  type = list(string)
}

variable "dap_export_bucket_name" {
  type = string
}

variable "bucket_manifest_location" {
  type = string
}
