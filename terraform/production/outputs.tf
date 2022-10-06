output "delta_internal_subnet_ids" {
  value = module.networking.delta_internal_subnets[*].id
}

output "vpc_id" {
  value = module.networking.vpc.id
}