##########################################################################
# Shared module, consumed by infra/app.
#
# It exists so we can test whether a change in modules/ correctly replans
# every directory that consumes it - see the modules/**/*.tf file pattern in
# .terrateam/config.yml.
##########################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "name" {
  description = "Instance name."
  type        = string
}

variable "vpc_id" {
  description = "VPC the instance belongs to, handed down from the network layer."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the instance sits in, handed down from the network layer."
  type        = string
}

variable "tier" {
  description = "Instance tier. Defaulted so consumers do not have to change to pick it up."
  type        = string
  default     = "standard"
}

resource "null_resource" "this" {
  triggers = {
    name      = var.name
    vpc_id    = var.vpc_id
    subnet_id = var.subnet_id
    tier      = var.tier
  }

  provisioner "local-exec" {
    command = "echo 'instance ${var.name} (${var.tier}) -> ${var.subnet_id} in ${var.vpc_id}'"
  }
}

output "id" {
  description = "Instance ID."
  value       = null_resource.this.id
}

output "name" {
  description = "Instance name."
  value       = var.name
}

output "tier" {
  description = "Instance tier."
  value       = var.tier
}
