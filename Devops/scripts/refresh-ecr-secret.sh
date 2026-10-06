#!/usr/bin/env bash
# Also run every six hours on the host using an existing IAM identity.
set -euo pipefail
set +x
: "${AWS_REGION:?set AWS_REGION}"
: "${AWS_ACCOUNT_ID:?set AWS_ACCOUNT_ID}"
[[ "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || { echo "Invalid AWS_ACCOUNT_ID" >&2; exit 1; }
[[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]] || { echo "Invalid AWS_REGION" >&2; exit 1; }
umask 077
credentials_dir=$(mktemp -d)
trap 'rm -rf "$credentials_dir"' EXIT
export REGISTRY_HOST="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
# Keep the password out of argv, logs, Git, and published artifacts.
aws ecr get-login-password --region "$AWS_REGION" | python3 -c '
import sys, os, json, base64
password = sys.stdin.read().strip()
if not password: raise SystemExit("Empty ECR token")
auth = base64.b64encode(("AWS:" + password).encode()).decode()
json.dump({"auths": {os.environ["REGISTRY_HOST"]: {"auth": auth}}}, sys.stdout)
' > "$credentials_dir/config.json"
kubectl -n kadianai-1 create secret generic ecr-pull \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$credentials_dir/config.json" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
echo "ECR pull secret refreshed."
