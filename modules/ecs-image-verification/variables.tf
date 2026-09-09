variable "lambda_name" {
  description = "Name of the Cosign verifier Lambda function."
  type        = string
}

variable "lambda_image_uri" {
  description = "Existing ECR URI for the Lambda container image."
  type        = string
}

variable "sns_topic_name" {
  description = "Name of the SNS topic used for verification alerts."
  type        = string
}

variable "email" {
  description = "Email address for SNS alert subscription."
  type        = string
}

variable "region" {
  description = "AWS region where the verifier is deployed."
  type        = string
}

variable "cluster_arns" {
  description = "ECS cluster ARNs to monitor. An empty list monitors all ECS clusters."
  type        = list(string)
  default     = []
}
