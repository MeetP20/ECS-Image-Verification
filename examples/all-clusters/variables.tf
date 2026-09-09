variable "lambda_name" {
  type        = string
  description = "Lambda function name."
}

variable "lambda_image_uri" {
  type        = string
  description = "Existing ECR URI of the Lambda container image."
}

variable "sns_topic_name" {
  type        = string
  description = "SNS topic name."
}

variable "email" {
  type        = string
  description = "Email address for SNS alerts."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "cluster_arns" {
  type        = list(string)
  description = "Leave empty to monitor all ECS clusters."
  default     = []
}
