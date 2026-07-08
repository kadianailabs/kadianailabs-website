# CI/CD Learning Project — Flask + Docker + Azure DevOps + AWS EC2

A deliberately small project to learn a full CI/CD pipeline end to end.
You build a tiny Flask web app, containerize it, and ship it to an EC2
instance using two Azure DevOps pipelines, with the AWS infrastructure
defined as code in CloudFormation.

## The big picture

```
   git push to main
        │
        ▼
┌──────────────────┐     ┌──────────────────┐     ┌────────────────────┐
│  BUILD pipeline  │     │  DEPLOY pipeline  │     │     EC2 (Docker)    │
│  (build.pipeline)│ ──▶ │ (deploy.pipeline) │ ──▶ │  pulls image & runs │
│  test→build→push │     │   ssh + pull/run  │     │   container :80     │
└──────────────────┘     └──────────────────┘     └────────────────────┘
        │                                                    ▲
        └────────────── pushes image to AWS ECR ─────────────┘
```

- **CI (build.pipeline.yml):** run tests → build Docker image → push to ECR.
- **CD (deploy.pipeline.yml):** SSH to EC2 → pull image → restart container.

## Repo structure

```
root/
├── Devops/                     # the CI/CD pipelines
│   ├── build.pipeline.yml      # CI: test, build, push image
│   ├── deploy.pipeline.yml     # CD: deploy image to EC2
│   └── scripts/
│       └── deploy.sh           # manual deploy (same steps, by hand)
├── Infra/
│   └── infra.yaml              # CloudFormation: ECR + EC2 + IAM + SG
└── src/
    └── Python/                 # the application
        ├── app.py              # Flask app (UI + small API)
        ├── templates/index.html
        ├── requirements.txt
        ├── test_app.py         # tests the CI runs
        ├── Dockerfile
        └── .dockerignore
```

## Run the app locally first

```bash
cd src/Python
pip install -r requirements.txt
python app.py            # open http://localhost:5000
pytest -v                # run the tests the pipeline runs
```

Or with Docker:

```bash
cd src/Python
docker build -t cicd-demo-app .
docker run -p 5000:5000 cicd-demo-app
```

## Step 1 — Create the AWS infrastructure (CloudFormation)

This creates the ECR repo and the EC2 box (with Docker auto-installed).

```bash
aws cloudformation deploy \
  --template-file Infra/infra.yaml \
  --stack-name cicd-demo \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      KeyName=YOUR_KEYPAIR \
      VpcId=vpc-xxxxxxxx \
      SubnetId=subnet-xxxxxxxx \
      SshAllowedCidr=YOUR_IP/32
```

When it finishes, grab the outputs (Console → CloudFormation → Outputs, or):

```bash
aws cloudformation describe-stacks --stack-name cicd-demo \
  --query "Stacks[0].Outputs"
```

Note the **EcrRepositoryUri**, **InstancePublicIp**, and **AppUrl**.

## Step 2 — Set up Azure DevOps

1. Push this repo to an Azure DevOps Git repo (or connect GitHub).
2. **Pipelines → New pipeline → Existing YAML file** → select
   `Devops/build.pipeline.yml`. Repeat for `Devops/deploy.pipeline.yml`.
3. Name the build pipeline **build.pipeline** (the deploy pipeline's
   `resources` block references it by that name).
4. Add pipeline **variables** (Pipeline → Edit → Variables):
   - `AWS_REGION` (e.g. `us-east-1`)
   - `AWS_ACCOUNT_ID` (your 12-digit account id)
   - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` — mark these **secret**.
5. Create an **SSH service connection** named `ec2-ssh`
   (Project Settings → Service connections → New → SSH):
   - Host = EC2 public IP, Username = `ec2-user`, paste your private key.

> Tip for real projects: instead of access-key variables, install the
> **AWS Toolkit for Azure DevOps** extension and use an AWS service
> connection. Keys-as-variables is used here just to keep it readable.

## Step 3 — Run it

- Push a commit to `main` → the **build** pipeline runs automatically:
  tests → image → ECR.
- When build succeeds, the **deploy** pipeline triggers, SSHes into EC2,
  pulls the image, and restarts the container.
- Open the **AppUrl** in a browser. The page shows the **version**
  (the build number) — change the code, push again, and watch the version
  bump after the next deploy. That's the whole CI/CD loop.

## How each piece teaches a concept

| File | Concept |
|------|---------|
| `test_app.py` | Automated tests gate the build (you can't ship red tests) |
| `Dockerfile` | Package once, run anywhere — immutable build artifact |
| `build.pipeline.yml` | Continuous Integration: test + build + publish |
| `deploy.pipeline.yml` | Continuous Deployment: promote the same artifact |
| `infra.yaml` | Infrastructure as Code — reproducible environments |
| ECR | An artifact registry — where built images live |
| Build number as version/tag | Traceability: what's running == what was built |

## Clean up (avoid charges)

```bash
# delete images first, then the stack
aws ecr batch-delete-image --repository-name cicd-demo-app \
  --image-ids imageTag=latest 2>/dev/null || true
aws cloudformation delete-stack --stack-name cicd-demo
```
