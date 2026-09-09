terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "ecs_image_verification" {
  source = "../../modules/ecs-image-verification"

  lambda_name     = var.lambda_name
  lambda_image_uri = var.lambda_image_uri
  sns_topic_name  = var.sns_topic_name
  email           = var.email
  region          = var.region
  cluster_arns    = var.cluster_arns
}
