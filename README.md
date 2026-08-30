# KadianAI LABS — Node.js frontend + Python backend, shipped via Azure Pipelines to AWS

The KadianAI site is split into two independently deployable services and shipped
through a two-stage Azure DevOps pipeline to an AWS EC2 host, with infrastructure
defined as code in CloudFormation. The layout follows the reference in
[`Devops-example/`](Devops-example/).

## The big picture

```
   git push to main
        │
        ▼
┌──────────────────┐     ┌───────────────────┐     ┌────────────────────────┐
│  BUILD pipeline  │     │  DEPLOY pipeline   │     │      EC2 (Docker)      │
│ (build.pipeline) │ ──▶ │ (deploy.pipeline)  │ ──▶ │ frontend :80  (Node)   │
│ test→build→push  │     │   ssh + pull/run   │     │ backend  :8000 (Python)│
└──────────────────┘     └───────────────────┘     └────────────────────────┘
        │                                                      ▲
        └───── pushes 2 images to AWS ECR (fe + be repos) ─────┘
```

- **CI (`build.pipeline.yml`)**: run Node tests + Python tests → build both Docker
  images → push both to ECR, tagged with the build number.
- **CD (`deploy.pipeline.yml`)**: SSH to EC2 → pull both images → restart both
  containers → health-check.

## Repo structure

```
root/
├── Devops/                     # the CI/CD pipelines
│   ├── build.pipeline.yml      # CI: test, build, push both images
│   ├── infra.pipeline.yml      # provision AWS infra (CloudFormation), on demand
│   ├── deploy.pipeline.yml     # CD: deploy both images to EC2
│   └── scripts/deploy.sh       # manual deploy (same steps, by hand)
├── Infra/
│   └── infra.yaml              # CloudFormation: EC2 + IAM + SG (ECR repos managed separately)
├── src/
│   ├── Node/                   # Node.js SSR frontend (Express + EJS)
│   │   ├── server.js           # server, security headers, /health
│   │   ├── views/index.ejs     # server-rendered landing page
│   │   ├── public/             # favicon, robots, sitemap, 404
│   │   ├── test/server.test.js # tests the CI runs (node --test)
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   └── .dockerignore
│   └── Python/                 # independent Python backend microservice (Flask)
│       ├── app.py              # JSON API + /health
│       ├── tests/test_app.py   # tests the CI runs (pytest)
│       ├── requirements.txt
│       ├── Dockerfile
│       └── .dockerignore
├── Devops-example/             # reference project this structure follows
└── (Kubernetes/Terraform files from the earlier EKS approach remain at root)
```

> The two services are **loosely coupled**: the Node frontend renders on its own
> and the Python backend is an independent microservice with its own concerns.

## Run locally

Frontend (Node):

```bash
cd src/Node
npm install
npm test            # node --test
npm start           # http://localhost:3000
```

Backend (Python):

```bash
cd src/Python
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest -v           # run the tests the pipeline runs
python app.py       # http://localhost:8000
```

With Docker:

```bash
docker build -t kadianai-frontend src/Node
docker run -p 3000:3000 kadianai-frontend

docker build -t kadianai-backend src/Python
docker run -p 8000:8000 kadianai-backend
```

## Step 1 — Create the AWS infrastructure (CloudFormation)

Creates the EC2 box (Docker auto-installed) + IAM role + security group. The two
ECR repos (`kadianai-frontend`, `kadianai-backend`) are managed separately — create
them once with `aws ecr create-repository` before the first build.

You can run this from your machine with the command below, **or** from Azure via
the **infra.pipeline** (which runs exactly this CloudFormation deploy). Both are
idempotent.

```bash
aws cloudformation deploy \
  --template-file Infra/infra.yaml \
  --stack-name kadianai \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      KeyName=YOUR_KEYPAIR \
      VpcId=vpc-xxxxxxxx \
      SubnetId=subnet-xxxxxxxx \
      SshAllowedCidr=YOUR_IP/32
```

Grab the outputs (**InstancePublicIp**, **FrontendUrl**, **BackendUrl**):

```bash
aws cloudformation describe-stacks --stack-name kadianai \
  --query "Stacks[0].Outputs"
```

## Step 2 — Set up Azure DevOps

1. Push this repo to an Azure DevOps Git repo (or connect GitHub).
2. **Pipelines → New pipeline → Existing YAML file** → create **three** pipelines,
   one per YAML file. Name them to match:
   - `Devops/build.pipeline.yml`  → name it **build.pipeline**
   - `Devops/infra.pipeline.yml`  → name it **infra.pipeline** (run on demand)
   - `Devops/deploy.pipeline.yml` → name it **deploy.pipeline** (it references
     **build.pipeline** by name, and triggers after it succeeds)
3. Add **variables** (a shared variable group is easiest — Pipelines → Library):
   - `AWS_REGION` (e.g. `us-east-1`)
   - `AWS_ACCOUNT_ID` (your 12-digit account id)
   - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` — mark these **secret**.
   - For **infra.pipeline** also: `KeyName`, `VpcId`, `SubnetId` (and optional
     `SshAllowedCidr`, `stackName`). Its AWS creds need broad permissions
     (CloudFormation/EC2/IAM), so prefer separate infra credentials.
4. Run **infra.pipeline** once to create the EC2 host; note the
   `InstancePublicIp` from its "Show stack outputs" log.
5. Create an **SSH service connection** named `ec2-ssh`
   (Project Settings → Service connections → New → SSH): host = that EC2 public
   IP, username = `ec2-user`, paste your private key.

## Step 3 — Run it

- Push to `main` → **build** runs: tests → two images → ECR.
- On success, **deploy** triggers, SSHes into EC2, pulls both images, restarts
  both containers.
- Open **FrontendUrl** (port 80). The footer shows the running **version**
  (the build number). Push again and watch it bump after the next deploy.

## Clean up (avoid charges)

```bash
aws ecr batch-delete-image --repository-name kadianai-frontend --image-ids imageTag=latest 2>/dev/null || true
aws ecr batch-delete-image --repository-name kadianai-backend  --image-ids imageTag=latest 2>/dev/null || true
aws cloudformation delete-stack --stack-name kadianai
```
