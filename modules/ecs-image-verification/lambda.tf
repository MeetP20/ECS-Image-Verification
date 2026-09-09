resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "verifier" {
  function_name = var.lambda_name
  description   = "Verifies Cosign signatures on ECS container images at task launch."

  package_type = "Image"
  image_uri    = var.lambda_image_uri

  role          = aws_iam_role.lambda.arn
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      ENVIRONMENT   = "terraform"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.basic_execution,
    aws_cloudwatch_log_group.lambda
  ]
}
