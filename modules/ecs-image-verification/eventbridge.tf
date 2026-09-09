resource "aws_cloudwatch_event_rule" "ecs_task_state_change" {
  name        = "${var.lambda_name}-ecs-task-verify"
  description = "Triggers the Cosign verifier when a monitored ECS task reaches RUNNING."

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Task State Change"]
    detail        = local.event_detail
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.ecs_task_state_change.name
  arn  = aws_lambda_function.verifier.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.verifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_task_state_change.arn
}
