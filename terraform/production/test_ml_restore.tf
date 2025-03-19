module "test_ml_restore" {
  source = "../modules/marklogic_restore_rehearsal"

  default_tags          = var.default_tags
  environment           = local.environment
  vpc                   = module.networking.vpc
  private_subnets       = module.networking.ml_restore_rehearsal_private_subnets
  instance_type         = "r5a.8xlarge" # r6a is not allowed (as of 26/02/2023)
  marklogic_ami_version = "10.0-10.2"
  data_volume = {
    size_gb                = 3000
    iops                   = 16000
    throughput_MiB_per_sec = 1000
  }

  // These give the test cluster permission to read any backup file
  daily_backup_bucket_arn  = module.marklogic.daily_backup_bucket_arn
  weekly_backup_bucket_arn = module.marklogic.weekly_backup_bucket_arn
  backup_key               = module.marklogic.backup_key
  locked_backup_replication_bucket_arn = module.backup_replication_bucket.bucket.arn
}
