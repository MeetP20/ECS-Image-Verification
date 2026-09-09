# 🔐 ECS-Image-Verification

> **Plug-in security layer for Amazon ECS clusters using Cosign image verification.**

This project verifies container image signatures when ECS tasks reach `RUNNING`. Unsigned containers are stopped and the team is alerted through SNS email.

No changes to existing ECS, ECR, or application infrastructure are required.

---

## 📐 Architecture

```text
Developer
   │
   │ cosign sign
   ▼
ECR
   │
   ▼
ECS Task reaches RUNNING
   │
   ▼
EventBridge
   │
   ▼
Lambda (container image)
   │
   │ cosign verify
   ├───────────────┐
   ▼               ▼
PASS            FAIL
 │                │
 ▼                ├── Stop ECS task
CloudWatch        └── SNS email alert
```

This remains a **post-start enforcement** flow: the verifier is triggered after the ECS task reaches `RUNNING`.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.12 |
| Signature verification | Cosign v2 |
| Compute | AWS Lambda (Container Image) |
| Event trigger | Amazon EventBridge |
| Alerting | Amazon SNS |
| Observability | Amazon CloudWatch |
| Infrastructure as Code | AWS CloudFormation / Terraform |

---

## 📁 Project Structure

```text
ECS-Image-Verification/
├── lambda/
│   ├── handler.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── cosign.pub
├── cloudformation/
│   └── stack.yaml
├── modules/
│   └── ecs-image-verification/
│       ├── main.tf
│       ├── variables.tf
│       ├── lambda.tf
│       ├── iam.tf
│       ├── sns.tf
│       ├── eventbridge.tf
│       ├── outputs.tf
│       └── README.md
├── examples/
│   ├── all-clusters/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars.example
│   │   └── outputs.tf
│   └── specific-clusters/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars.example
│       └── outputs.tf
└── README.md
```

---

# 🚀 Terraform Module

The Terraform module packages the existing CloudFormation architecture as a reusable module.

The user only needs to provide:

- Lambda function name
- Existing Lambda container image ECR URI
- SNS topic name
- Email address
- AWS region
- ECS cluster ARN list

The module creates Lambda, EventBridge, SNS, IAM, and CloudWatch resources. It does **not** create an ECR repository and does **not** build or push the Lambda image.

## Monitor all ECS clusters

An empty `cluster_arns` list means all ECS clusters in the selected AWS region/account are monitored.

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

## Monitor selected ECS clusters

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

### Terraform example with `.tfvars`

```text
examples/
├── all-clusters/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── outputs.tf
└── specific-clusters/
    ├── main.tf
    ├── variables.tf
    ├── terraform.tfvars.example
    └── outputs.tf
```

Copy `terraform.tfvars.example` to `terraform.tfvars`, replace the example values, and run:

```bash
terraform init
terraform plan
terraform apply
```

After deployment, confirm the SNS email subscription.

---

# ☁️ CloudFormation

The original CloudFormation deployment remains available under `cloudformation/stack.yaml`.

It accepts the Lambda container image URI and alert email and monitors all ECS clusters by default.

The Lambda image should be built and pushed to an existing ECR repository first.

```bash
docker build --platform linux/amd64 \
  -t 123456789012.dkr.ecr.ap-south-1.amazonaws.com/ecs-image-verifier:v1.0.0 \
  ./lambda

docker push 123456789012.dkr.ecr.ap-south-1.amazonaws.com/ecs-image-verifier:v1.0.0
```

---

## 🔒 Security Notes

- Never commit `cosign.key`.
- `cosign.pub` is a public key and can be bundled with the Lambda image.
- The Lambda requires ECR read access to verify application image signatures.
- `--insecure-ignore-tlog` is currently used by the verifier for signature verification without Rekor transparency-log verification.

---

## ⚠️ Important Architecture Note

The solution verifies images after the ECS task has reached `RUNNING`. It is therefore not a pre-start admission controller. An unsigned task can run briefly before EventBridge invokes Lambda and Lambda stops the task.

---

## 🧹 Terraform Teardown

From either Terraform example directory:

```bash
terraform destroy
```

This removes resources created by the module and does not delete the user's ECS clusters or existing ECR repositories.
