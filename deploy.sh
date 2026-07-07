#!/bin/bash
# ─────────────────────────────────────────────────────────
# KadianAI LABS — AWS Amplify Deployment Script
# ─────────────────────────────────────────────────────────
# Prerequisites:
#   1. AWS CLI installed and configured (aws configure)
#   2. GitHub repo created and pushed
#   3. Amplify CLI installed: npm install -g @aws-amplify/cli
# ─────────────────────────────────────────────────────────

set -e

APP_NAME="kadianailabs-website"
REGION="us-east-1"   # US East (N. Virginia) — closest to Toronto
BRANCH="main"

echo "═══════════════════════════════════════════════════"
echo "  KadianAI LABS — AWS Amplify Deployment"
echo "═══════════════════════════════════════════════════"
echo ""

# ─── Step 1: Check prerequisites ───
echo "[1/5] Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found. Install it first:"
    echo "  brew install awscli"
    echo "  aws configure"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "ERROR: Git not found."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured. Run:"
    echo "  aws configure"
    exit 1
fi

echo "  AWS CLI: OK"
echo "  Git: OK"
echo "  AWS Credentials: OK"
echo ""

# ─── Step 2: Get GitHub repo URL ───
echo "[2/5] Detecting GitHub repository..."

REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")

if [ -z "$REPO_URL" ]; then
    echo "ERROR: No remote origin found. Push to GitHub first:"
    echo ""
    echo "  1. Create a new repo at https://github.com/new"
    echo "  2. Run:"
    echo "     git remote add origin https://github.com/YOUR_USERNAME/$APP_NAME.git"
    echo "     git push -u origin main"
    echo ""
    echo "  3. Then re-run this script."
    exit 1
fi

echo "  Repo: $REPO_URL"
echo ""

# ─── Step 3: Create Amplify app ───
echo "[3/5] Creating Amplify app..."

# Check if app already exists
EXISTING_APP=$(aws amplify list-apps --region $REGION --query "apps[?name=='$APP_NAME'].appId" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_APP" ] && [ "$EXISTING_APP" != "None" ]; then
    APP_ID=$EXISTING_APP
    echo "  App already exists: $APP_ID"
else
    # Create new Amplify app
    APP_ID=$(aws amplify create-app \
        --name "$APP_NAME" \
        --repository "$REPO_URL" \
        --region "$REGION" \
        --platform "WEB" \
        --build-spec "$(cat amplify.yml)" \
        --custom-headers "$(cat customHttp.yml)" \
        --environment-variables "AMPLIFY_MONOREPO_APP_ROOT=" \
        --query 'app.appId' \
        --output text)
    echo "  Created app: $APP_ID"
fi
echo ""

# ─── Step 4: Create branch ───
echo "[4/5] Connecting branch '$BRANCH'..."

EXISTING_BRANCH=$(aws amplify list-branches --app-id "$APP_ID" --region $REGION --query "branches[?branchName=='$BRANCH'].branchName" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_BRANCH" ] && [ "$EXISTING_BRANCH" != "None" ]; then
    echo "  Branch already connected."
else
    aws amplify create-branch \
        --app-id "$APP_ID" \
        --branch-name "$BRANCH" \
        --region "$REGION" \
        --stage "PRODUCTION" \
        --enable-auto-build \
        --output text > /dev/null
    echo "  Branch connected with auto-build enabled."
fi
echo ""

# ─── Step 5: Trigger first deployment ───
echo "[5/5] Triggering deployment..."

JOB_ID=$(aws amplify start-job \
    --app-id "$APP_ID" \
    --branch-name "$BRANCH" \
    --job-type "RELEASE" \
    --region "$REGION" \
    --query 'jobSummary.jobId' \
    --output text)

echo "  Deployment started! Job ID: $JOB_ID"
echo ""

# ─── Summary ───
DEFAULT_DOMAIN="https://${BRANCH}.${APP_ID}.amplifyapp.com"

echo "═══════════════════════════════════════════════════"
echo "  DEPLOYMENT STARTED SUCCESSFULLY"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  App ID:    $APP_ID"
echo "  Region:    $REGION"
echo "  Branch:    $BRANCH"
echo "  URL:       $DEFAULT_DOMAIN"
echo ""
echo "  Monitor:   https://$REGION.console.aws.amazon.com/amplify/home?region=$REGION#/$APP_ID"
echo ""
echo "  The site will be live in ~2-3 minutes."
echo ""
echo "═══════════════════════════════════════════════════"
echo "  NEXT STEPS (when you get a domain):"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  1. Go to Amplify Console > Domain Management"
echo "  2. Click 'Add domain'"
echo "  3. Enter 'kadianailabs.com'"
echo "  4. Amplify will auto-provision an SSL certificate"
echo "  5. Update your DNS with the provided CNAME records"
echo ""
