module "dap_export_bucket" {
  source = "../s3_bucket"

  bcuket_name            = "dluhc-delta-dap-export-${var.environment}"
  access_log_bucket_name = "dluhc-delta-dap-export-access-logs-${var.environment}"
}
