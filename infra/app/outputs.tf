output "consumed_vpc_id" {
  description = "Proof that the network layer's output made it across state boundaries."
  value       = local.vpc_id
}

output "consumed_subnet_ids" {
  description = "Subnets this layer was handed by the network layer."
  value       = local.subnet_ids
}

output "instance_count" {
  description = "Number of fake app instances, derived from the upstream subnet count."
  value       = local.instance_count
}

output "app_config_path" {
  description = "Where the rendered app config landed."
  value       = local_file.app_config.filename
}
