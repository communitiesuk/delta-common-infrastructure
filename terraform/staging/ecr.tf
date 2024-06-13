# Currently used by auth service for pulling AWS telemetry sidecar
resource "aws_ecr_pull_through_cache_rule" "ecr_public2" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}
