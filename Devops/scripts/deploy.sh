#!/bin/bash
# -----------------------------------------------------------------------------
# Manual deploy script. The DEPLOY pipeline runs the same steps over SSH,
# but you can also run this directly ON the EC2 box to test by hand.
#
# It deploys BOTH services:
#   - kadianai-frontend (Node SSR)  -> published on port 80  (container :3000)
#   - kadianai-backend  (Python API) -> published on port 8000 (container :8000)
#
# Usage (on EC2):
#   AWS_REGION=us-east-1 AWS_ACCOUNT_ID=123456789012 IMAGE_TAG=latest ./deploy.sh
# -----------------------------------------------------------------------------
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?set AWS_ACCOUNT_ID}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

FRONTEND_NAME="kadianai-frontend"
BACKEND_NAME="kadianai-backend"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

FRONTEND_IMAGE="${REGISTRY}/${FRONTEND_NAME}:${IMAGE_TAG}"
BACKEND_IMAGE="${REGISTRY}/${BACKEND_NAME}:${IMAGE_TAG}"

echo ">> Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> Pulling images..."
docker pull "$FRONTEND_IMAGE"
docker pull "$BACKEND_IMAGE"

echo ">> (Re)starting backend..."
docker rm -f "$BACKEND_NAME" 2>/dev/null || true
docker run -d --restart unless-stopped \
  --name "$BACKEND_NAME" \
  -p 8000:8000 \
  "$BACKEND_IMAGE"

echo ">> (Re)starting frontend..."
docker rm -f "$FRONTEND_NAME" 2>/dev/null || true
docker run -d --restart unless-stopped \
  --name "$FRONTEND_NAME" \
  -p 80:3000 \
  "$FRONTEND_IMAGE"

echo ">> Health checks..."
sleep 3
curl -fs http://localhost/health        && echo " -> frontend OK"
curl -fs http://localhost:8000/health   && echo " -> backend OK"
