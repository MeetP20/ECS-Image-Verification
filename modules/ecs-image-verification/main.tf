terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  event_detail = merge(
    {
      lastStatus = ["RUNNING"]
    },
    length(var.cluster_arns) > 0 ? {
      clusterArn = var.cluster_arns
    } : {}
  )
}
