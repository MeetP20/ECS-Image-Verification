# 🔐 Cosign ECS Image Verifier

> **Plug-in security layer for all your Amazon ECS clusters in a region.**  
> Deploy this once and every container across every ECS cluster in the region is automatically verified against a Cosign signature. Unsigned containers are stopped instantly and your team is alerted via email.

No changes to your existing ECS, ECR, or application infrastructure required.

---

## 📐 Architecture

```
Your existing setup            This project adds
──────────────────             ─────────────────────────────────────

  Developer                      cosign sign --key cosign.key <image>
     │                                        │
     ▼                                        ▼
  Push image ────────────────► ECR (signed image stored)
                                              │
  Any ECS Task starts (RUNNING) ◄────────────┘
  across any cluster in region
     │
     ▼
  EventBridge Rule ────────────► Lambda (container image)
  (watches ALL clusters)         ┌────────────────────────┐
                                 │  cosign binary  (baked) │
                                 │  cosign.pub key (baked) │
                                 │  handler.py             │
                                 └────────────┬───────────┘
                                              │
                                 cosign verify <image>
                                              │
                                 ┌────────────┴────────────┐
                                 ▼                         ▼
                              PASS ✅                   FAIL ❌
                           Log success              Stop ECS task
                           to CloudWatch          + SNS email alert 📧
```

### What gets deployed (only these 5 resources)

| Resource | Purpose |
|---|---|
| **Lambda Function** (container image) | Runs cosign verification on each task |
| **EventBridge Rule** | Watches **all ECS clusters** in the region for RUNNING tasks |
| **SNS Topic + Subscription** | Sends email alerts when a container is blocked |
| **IAM Role** | Least-privilege permissions for Lambda |
| **CloudWatch Log Group** | Stores Lambda verification logs |

> Your ECS clusters, ECR repositories, VPC, and application code are untouched.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Language | Python 3.12 |
| Signature verification | Cosign v2 (Sigstore) |
| Compute | AWS Lambda (Container Image) |
| Event trigger | Amazon EventBridge |
| Alerting | Amazon SNS |
| Observability | Amazon CloudWatch |
| Infrastructure as Code | AWS CloudFormation |
| CI/CD | GitHub Actions |

### Why Lambda as a Container Image?
- **cosign binary baked in** — no runtime downloads, no Lambda Layers, no cold-start overhead
- **Public key bundled with code** — immutable trust anchor, no KMS dependency needed
- **Consistent environment** — same image runs locally and in production

---

## 📁 Project Structure

```
cosign-ecs-verify/
├── lambda/
│   ├── handler.py          # Python Lambda — verifies images, stops tasks, sends alerts
│   ├── Dockerfile          # Multi-stage build with cosign binary baked in
│   ├── requirements.txt    # Python dependencies (boto3)
│   └── cosign.pub          # Your Cosign public key (replace placeholder)
├── cloudformation/
│   └── stack.yaml          # Plug-in stack: Lambda + EventBridge + SNS + IAM
├── .github/
│   └── workflows/
│       └── build-push.yml  # CI/CD: auto-rebuild Lambda image on code change
├── .gitignore              # cosign.key excluded
└── README.md
```

---

## 🚀 Setup Guide

### Prerequisites

- AWS CLI configured (`aws configure`)
- Docker installed and running
- [Cosign installed](https://docs.sigstore.dev/cosign/system_config/installation/)
- IAM permissions for Lambda, EventBridge, SNS, IAM, CloudFormation, ECR

---

### Step 1 — Generate a Cosign Key Pair

```bash
cosign generate-key-pair
```

This produces:
- `cosign.key` — private key (**never commit this**)
- `cosign.pub` — public key (safe to bundle in the Lambda image)

Copy the public key into the lambda directory:

```bash
cp cosign.pub lambda/cosign.pub
```

> ⚠️ `cosign.key` is already in `.gitignore`. Double-check before your first `git push`.

---

### Step 2 — Sign Your Existing Container Images

> ⚠️ Sign **all** images your ECS tasks reference **before** deploying the verifier — once the stack is live, any unsigned container across any cluster in the region will be stopped immediately.

```bash
cosign sign --key cosign.key <your-ecr-image-uri>

# Example
cosign sign --key cosign.key 123456789012.dkr.ecr.us-east-1.amazonaws.com/your-app:latest
```

Verify the signature was applied correctly:

```bash
cosign verify --key cosign.pub --insecure-ignore-tlog <your-ecr-image-uri>
```

---

### Step 3 — Build and Push the Lambda Container Image

Create an ECR repository for the Lambda image:

```bash
aws ecr create-repository \
  --repository-name cosign-verifier \
  --image-scanning-configuration scanOnPush=true \
  --region us-east-1
```

Authenticate Docker to ECR:

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

Build and push the Lambda image:

```bash
docker build --platform linux/amd64 \
  -t 123456789012.dkr.ecr.us-east-1.amazonaws.com/cosign-verifier:latest \
  ./lambda

docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/cosign-verifier:latest
```

---

### Step 4 — Deploy the CloudFormation Stack

```bash
aws cloudformation deploy \
  --template-file cloudformation/stack.yaml \
  --stack-name cosign-ecs-verify \
  --parameter-overrides \
      LambdaImageUri=123456789012.dkr.ecr.us-east-1.amazonaws.com/cosign-verifier:latest \
      AlertEmail=your@email.com \
      Environment=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Once deployed, the EventBridge rule starts watching **all ECS clusters** in `us-east-1` immediately — no further configuration needed.

> After deployment, **confirm the SNS email subscription** from the email AWS sends you — alerts won't be delivered until you confirm.

Prefer the AWS Console? Upload `cloudformation/stack.yaml` via CloudFormation → Create Stack and fill in the parameters form.

---

### Step 5 — Verify It's Working

Tail the Lambda logs after running any ECS task:

```bash
aws logs tail /aws/lambda/cosign-ecs-verifier-dev --follow
```

**Signed image (should pass ✅):**
```
[INFO] Verifying image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest
[INFO] [PASS] Image verified successfully.
```

**Unsigned image (should be blocked ❌):**
```
[INFO] Verifying image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/app:unsigned
[WARNING] [FAIL] Verification failed for: ...
[INFO] Stopped task: arn:aws:ecs:...
[INFO] SNS alert sent successfully.
```

---

## ⚙️ CloudFormation Parameters

| Parameter | Required | Description | Default |
|---|---|---|---|
| `LambdaImageUri` | ✅ | ECR URI of the Lambda container image | — |
| `AlertEmail` | ✅ | Email for SNS notifications | — |
| `Environment` | | Deployment environment tag | `dev` |
| `LogRetentionDays` | | CloudWatch log retention in days | `30` |
| `LambdaTimeout` | | Lambda timeout in seconds | `60` |
| `LambdaMemory` | | Lambda memory in MB | `256` |

---

## 🎯 Applying to a Single Cluster Only

By default this stack monitors **all ECS clusters in the region**. To restrict it to a specific cluster, edit the EventBridge rule's `EventPattern` in `cloudformation/stack.yaml`:

```yaml
# Current — matches all clusters in the region
EventPattern:
  source:
    - aws.ecs
  detail-type:
    - ECS Task State Change
  detail:
    lastStatus:
      - RUNNING

# Change to — matches one specific cluster only
EventPattern:
  source:
    - aws.ecs
  detail-type:
    - ECS Task State Change
  detail:
    clusterArn:
      - arn:aws:ecs:us-east-1:123456789012:cluster/your-cluster-name
    lastStatus:
      - RUNNING
```

And update the IAM policy's `Resource` from:
```yaml
Resource: !Sub "arn:aws:ecs:${AWS::Region}:${AWS::AccountId}:task/*"
```
to the specific cluster:
```yaml
Resource: !Sub "arn:aws:ecs:${AWS::Region}:${AWS::AccountId}:task/your-cluster-name/*"
```

---

## 🔄 CI/CD with GitHub Actions

The `.github/workflows/build-push.yml` workflow automatically rebuilds and pushes the Lambda image whenever code in `lambda/` changes, then updates the Lambda function.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | IAM Role ARN for GitHub Actions OIDC (no long-lived keys needed) |

---

## 🔒 Security Notes

- **`cosign.key` must never be committed** — it's in `.gitignore` but always verify before pushing
- **`cosign.pub` is intentionally in the image** — it's a public key, safe to bundle
- **IAM follows least privilege** — Lambda can only stop ECS tasks, nothing else
- **`--insecure-ignore-tlog`** skips Rekor transparency log for private/offline verification — remove this flag if you want public Rekor logging

---

## 🧹 Teardown

To remove everything this project deployed (your ECS clusters are completely unaffected):

```bash
aws cloudformation delete-stack \
  --stack-name cosign-ecs-verify \
  --region us-east-1
```