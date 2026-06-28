#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# deploy.sh — Deploy the Cosign ECS Verify CloudFormation stack
# Usage: ./scripts/deploy.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ── Configuration — update these before deploying ────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="cosign-verifier"
STACK_NAME="cosign-ecs-verify"
ENVIRONMENT="${ENVIRONMENT:-dev}"
ALERT_EMAIL="${ALERT_EMAIL:-}"   # Set via env var or prompt below

# ── Prompt for email if not set ───────────────────────────────
if [[ -z "$ALERT_EMAIL" ]]; then
  read -rp "Enter alert email address: " ALERT_EMAIL
fi

LAMBDA_IMAGE_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"

echo ""
echo "🚀 Deploying stack: ${STACK_NAME}"
echo "   Region      : ${AWS_REGION}"
echo "   Account     : ${AWS_ACCOUNT_ID}"
echo "   Environment : ${ENVIRONMENT}"
echo "   Lambda image: ${LAMBDA_IMAGE_URI}"
echo "   Alert email : ${ALERT_EMAIL}"
echo ""

# ── Step 1: Build and push Lambda image ──────────────────────
echo "📦 Step 1/3 — Building Lambda container image..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin \
  "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build \
  --platform linux/amd64 \
  -t "${LAMBDA_IMAGE_URI}" \
  ./lambda

docker push "${LAMBDA_IMAGE_URI}"
echo "✅ Image pushed to ECR: ${LAMBDA_IMAGE_URI}"

# ── Step 2: Deploy CloudFormation stack ──────────────────────
echo ""
echo "☁️  Step 2/3 — Deploying CloudFormation stack..."
aws cloudformation deploy \
  --template-file cloudformation/stack.yaml \
  --stack-name "${STACK_NAME}-${ENVIRONMENT}" \
  --parameter-overrides \
      LambdaImageUri="${LAMBDA_IMAGE_URI}" \
      AlertEmail="${ALERT_EMAIL}" \
      Environment="${ENVIRONMENT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${AWS_REGION}"

echo "✅ CloudFormation stack deployed."

# ── Step 3: Print outputs ─────────────────────────────────────
echo ""
echo "📋 Step 3/3 — Stack Outputs:"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}-${ENVIRONMENT}" \
  --region "${AWS_REGION}" \
  --query "Stacks[0].Outputs" \
  --output table

echo ""
echo "🎉 Deployment complete!"
echo "   ✉️  Check your email (${ALERT_EMAIL}) to confirm the SNS subscription."
