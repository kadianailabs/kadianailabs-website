#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:?set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?set AWS_ACCOUNT_ID}"
: "${ECR_REPOSITORY:?set ECR_REPOSITORY to an existing repository}"
tag="${1:-$(git rev-parse HEAD)}"
[[ "$tag" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ && "$tag" != latest ]] \
  || { echo "Use a valid traceable image tag" >&2; exit 1; }
registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
image="$registry/$ECR_REPOSITORY:$tag"
umask 077
export DOCKER_CONFIG=$(mktemp -d)
trap 'rm -rf "$DOCKER_CONFIG"' EXIT
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$registry"
docker build --platform "${IMAGE_PLATFORM:-linux/amd64}" \
  --build-arg "APP_VERSION=$tag" -t "$image" .
docker push "$image"
echo "Pushed $image"
