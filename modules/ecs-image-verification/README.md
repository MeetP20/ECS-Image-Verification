# ECS Image Verification Terraform Module

Reusable Terraform module for the existing ECS image-verification architecture.

The module does **not** create or modify ECS clusters, ECS services, ECR repositories, or application infrastructure. The user supplies the URI of an already-published Lambda container image.

## Inputs

Only six inputs are required:

| Variable | Description |
|---|---|
| `lambda_name` | Lambda function name |
| `lambda_image_uri` | Existing ECR URI of the Lambda container image |
| `sns_topic_name` | SNS topic name |
| `email` | Email address for SNS alerts |
| `region` | AWS region |
| `cluster_arns` | ECS clusters to monitor; empty list means all clusters |

## Usage

### Monitor all ECS clusters

```hcl
module "ecs_image_verification" {
  source = "github.com/MeetP20/ECS-Image-Verification//modules/ecs-image-verification"

  lambda_name      = "ecs-image-verifier"
  lambda_image_uri = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/ecs-image-verifier:v1.0.0"
  sns_topic_name   = "ecs-image-verification-alerts"
  email            = "security@example.com"
  region           = "ap-south-1"

  cluster_arns = []
}
```

### Monitor selected ECS clusters

```hcl
module "ecs_image_verification" {
  source = "github.com/MeetP20/ECS-Image-Verification//modules/ecs-image-verification"

  lambda_name      = "ecs-image-verifier"
  lambda_image_uri = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/ecs-image-verifier:v1.0.0"
  sns_topic_name   = "ecs-image-verification-alerts"
  email            = "security@example.com"
  region           = "ap-south-1"

  cluster_arns = [
    "arn:aws:ecs:ap-south-1:123456789012:cluster/production",
    "arn:aws:ecs:ap-south-1:123456789012:cluster/payment"
  ]
}
```

## Behavior

- `cluster_arns = []` → EventBridge monitors ECS task state changes for all clusters in the selected region/account.
- Non-empty `cluster_arns` → EventBridge filters events to only those clusters.
- The rule triggers when an ECS task reaches `RUNNING`.
- Lambda verifies every container image with Cosign.
- Failed verification stops the ECS task and publishes an SNS alert.

## What the module creates

- Lambda function using the supplied ECR container image
- EventBridge rule and Lambda target
- Lambda invoke permission for EventBridge
- SNS topic and email subscription
- Lambda IAM role and required permissions
- CloudWatch log group

The runtime architecture is unchanged from the original CloudFormation implementation.
