#!/usr/bin/env bash
set -euo pipefail
: "${WEBSITE_IMAGE:?set WEBSITE_IMAGE to the exact registry/repository:tag}"
# Require a traceable tag (or immutable digest), never latest or a placeholder.
[[ "$WEBSITE_IMAGE" =~ ^[a-z0-9.-]+(:[0-9]+)?/[a-z0-9._/-]+(:[a-zA-Z0-9_][a-zA-Z0-9_.-]*|@sha256:[a-f0-9]{64})$ ]] \
  || { echo "Invalid or untagged WEBSITE_IMAGE" >&2; exit 1; }
[[ "$WEBSITE_IMAGE" != *:latest && "$WEBSITE_IMAGE" != *:unconfigured ]] \
  || { echo "Use a traceable image tag" >&2; exit 1; }
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
umask 077
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT
# Render before applying: no transient placeholder image or extra revision.
kubectl set image --local -f "$repo_root/k8s/deployment.yaml" \
  "web=$WEBSITE_IMAGE" -o yaml > "$rendered"
kubectl apply -f "$repo_root/k8s/namespace.yaml"
# Bootstrap the valid TLS certificate out of band; never serve a default certificate.
kubectl -n kadianai-1 get secret website-tls -o name >/dev/null
if [[ "${REFRESH_ECR_SECRET:-true}" == true ]]; then
  bash "$repo_root/Devops/scripts/refresh-ecr-secret.sh"
fi
kubectl -n kadianai-1 get secret ecr-pull -o name >/dev/null
kubectl apply -f "$repo_root/k8s/service.yaml"
kubectl apply -f "$rendered"
kubectl apply -f "$repo_root/k8s/ingress.yaml"
kubectl -n kadianai-1 rollout status deployment/kadianai-website --timeout=120s
