#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# sign-image.sh — Sign a container image with Cosign
# Usage: ./scripts/sign-image.sh <image-uri>
# ─────────────────────────────────────────────────────────────
set -euo pipefail

IMAGE_URI="${1:-}"

if [[ -z "$IMAGE_URI" ]]; then
  echo "Usage: $0 <image-uri>"
  echo "Example: $0 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp:latest"
  exit 1
fi

if [[ ! -f "lambda/cosign.key" ]]; then
  echo "❌ cosign.key not found in lambda/ directory."
  echo "   Generate a key pair first: cosign generate-key-pair"
  echo "   Then place cosign.key and cosign.pub in the lambda/ directory."
  exit 1
fi

echo "🔐 Signing image: ${IMAGE_URI}"
cosign sign --key lambda/cosign.key "${IMAGE_URI}"
echo "✅ Image signed successfully."

echo ""
echo "🔍 Verifying signature..."
cosign verify --key lambda/cosign.pub --insecure-ignore-tlog "${IMAGE_URI}"
echo "✅ Signature verified."
