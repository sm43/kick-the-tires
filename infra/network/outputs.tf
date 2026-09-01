output "environment" {
  description = "Environment name."
  value       = var.environment
}

output "vpc_id" {
  description = "Fake VPC ID. Consumed by infra/app."
  value       = "vpc-${random_id.vpc.hex}"
}

output "cidr_block" {
  description = "Base CIDR of the fake network."
  value       = var.cidr_block
}

output "subnet_ids" {
  description = "Fake subnet IDs. Consumed by infra/app to decide how many instances to build."
  value       = [for s in random_id.subnet : "subnet-${s.hex}"]
}

output "subnet_cidrs" {
  description = "CIDR carved out per fake subnet."
  value       = [for i in range(var.subnet_count) : cidrsubnet(var.cidr_block, 8, i)]
}

output "internal_endpoint" {
  description = "Marked sensitive only to see how Terrateam renders sensitive values in plan comments."
  value       = "internal-${random_id.vpc.hex}.demo.local"
  sensitive   = true
}
