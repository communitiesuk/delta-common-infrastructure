variable "bucket_name" {
  type = string
}

variable "access_log_bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Optional. KMS key to encrypt bucket and access logs bucket."
}

variable "force_destroy" {
  description = "Allow the buckets to be destroyed by Terraform even if they are not empty."
  default     = false
}

variable "restrict_public_buckets" {
  description = "Value for the restrict_public_buckets option of the public access block. Must be false to share buckets across accounts"
  default     = true
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Set to null to skip creating a bucket lifecycle configuration"
  default     = 180
}

variable "access_s3_log_expiration_days" {
  type = number
}

variable "policy" {
  description = "optional policy json to append to default bucket enforce ssl policy"
  type        = string
  default     = null
}
