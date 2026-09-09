output "lambda_function_name" {
  description = "Name of the Cosign verifier Lambda function."
  value       = aws_lambda_function.verifier.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Cosign verifier Lambda function."
  value       = aws_lambda_function.verifier.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS alert topic."
  value       = aws_sns_topic.alerts.arn
}

output "eventbridge_rule_arn" {
  description = "ARN of the ECS task state-change EventBridge rule."
  value       = aws_cloudwatch_event_rule.ecs_task_state_change.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group used by the Lambda function."
  value       = aws_cloudwatch_log_group.lambda.name
}
