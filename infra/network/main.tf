terraform {
  required_version = ">= 1.5"

  # The state file lives next to this config and is committed to git, because
  # that is how the app layer reads these outputs while the demo has no cloud
  # credentials. Replace this block with an S3/GCS/AzureRM backend once you
  # have them - the resources and outputs below do not change.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "environment" {
  description = "Environment name, exported for the app layer to pick up."
  type        = string
  default     = "dev"
}

variable "cidr_block" {
  description = "Base CIDR the fake subnets are carved out of."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "How many fake subnets to hand to the app layer."
  type        = number
  default     = 2
}

# Stands in for a VPC. random_id behaves like a cloud-assigned identifier for
# demo purposes: generated once on apply, then read back out of state on every
# later run, so downstream layers see a stable value.
resource "random_id" "vpc" {
  byte_length = 4

  keepers = {
    environment = var.environment
  }
}

resource "random_id" "subnet" {
  count       = var.subnet_count
  byte_length = 4

  keepers = {
    environment = var.environment
    subnet      = count.index
  }
}

resource "null_resource" "vpc_ready" {
  triggers = {
    vpc_id = random_id.vpc.hex
  }

  provisioner "local-exec" {
    command = "echo 'network layer ready: vpc-${random_id.vpc.hex} (${var.environment})'"
  }
}
