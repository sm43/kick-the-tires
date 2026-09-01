terraform {
  required_version = ">= 1.5"

  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# The point of the two-layer setup: read the network layer's outputs rather than
# duplicating its values. When network moves to a real backend, this data source
# is the only thing that needs editing.
data "terraform_remote_state" "network" {
  backend = "local"

  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

locals {
  environment  = data.terraform_remote_state.network.outputs.environment
  vpc_id       = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids   = data.terraform_remote_state.network.outputs.subnet_ids
  subnet_cidrs = data.terraform_remote_state.network.outputs.subnet_cidrs

  instance_count = length(local.subnet_ids) * var.instances_per_subnet
}

variable "instances_per_subnet" {
  description = "Bump this to see an app-only plan that leaves the network layer untouched."
  type        = number
  default     = 1
}

resource "null_resource" "instance" {
  count = local.instance_count

  triggers = {
    vpc_id    = local.vpc_id
    subnet_id = local.subnet_ids[count.index % length(local.subnet_ids)]
  }

  provisioner "local-exec" {
    command = "echo 'app instance ${count.index} -> ${local.subnet_ids[count.index % length(local.subnet_ids)]} in ${local.vpc_id}'"
  }
}

# Rendered on every run so the plan diff spells out the values that crossed over
# from the network layer. Easiest way to confirm the wiring from a PR comment.
resource "local_file" "app_config" {
  filename = "${path.module}/generated/app-config.json"

  content = jsonencode({
    environment    = local.environment
    vpc_id         = local.vpc_id
    subnet_ids     = local.subnet_ids
    subnet_cidrs   = local.subnet_cidrs
    instance_count = local.instance_count
  })
}
