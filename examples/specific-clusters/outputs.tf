output "lambda_function_name" {
  value = module.ecs_image_verification.lambda_function_name
}

output "lambda_function_arn" {
  value = module.ecs_image_verification.lambda_function_arn
}

output "sns_topic_arn" {
  value = module.ecs_image_verification.sns_topic_arn
}

output "eventbridge_rule_arn" {
  value = module.ecs_image_verification.eventbridge_rule_arn
}

output "cloudwatch_log_group" {
  value = module.ecs_image_verification.cloudwatch_log_group
}
