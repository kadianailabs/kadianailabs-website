#!/bin/bash
# ─────────────────────────────────────────────────────────
# KadianAI LABS — build the site image and push to ECR.
# Usage: ./build-and-push.sh [tag]   (default tag: git short SHA)
# Requires: docker, aws CLI. Run `terraform apply` first so ECR exists.
# ─────────────────────────────────────────────────────────
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-kadianai-website}"
TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

echo "── Logging in to ECR (${REGION}) ──"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "── Building image: ${ECR_URL}:${TAG} ──"
# Build for the cluster's arch (amd64 nodes by default).
docker build --platform linux/amd64 -t "${ECR_URL}:${TAG}" -t "${ECR_URL}:latest" .

echo "── Pushing ──"
docker push "${ECR_URL}:${TAG}"
docker push "${ECR_URL}:latest"

echo ""
echo "Pushed ${ECR_URL}:${TAG}"
echo ""
echo "Deploy it with:"
echo "  cd k8s && kustomize edit set image ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/kadianai-website=${ECR_URL}:${TAG} && kubectl apply -k ."
