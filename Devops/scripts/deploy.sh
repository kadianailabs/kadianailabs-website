#!/bin/bash
# -----------------------------------------------------------------------------
# Manual deploy script. The DEPLOY pipeline does the same steps over SSH,
# but you can also run this directly ON the EC2 box to test by hand.
#
# Usage (on EC2):
#   AWS_REGION=us-east-1 AWS_ACCOUNT_ID=123456789012 IMAGE_TAG=latest ./deploy.sh
# -----------------------------------------------------------------------------
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?set AWS_ACCOUNT_ID}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_NAME="cicd-demo-app"

REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ">> Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> Pulling $IMAGE ..."
docker pull "$IMAGE"

echo ">> Restarting container..."
docker rm -f "$IMAGE_NAME" 2>/dev/null || true
docker run -d --restart unless-stopped \
  --name "$IMAGE_NAME" \
  -p 80:5000 \
  "$IMAGE"

echo ">> Health check..."
sleep 3
curl -fs http://localhost/health && echo " -> deploy OK"
