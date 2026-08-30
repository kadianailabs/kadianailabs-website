# KadianAI LABS — Kubernetes on AWS (EKS)

Deploy the static site to **Amazon EKS** as a containerized nginx workload,
with all infrastructure managed by **Terraform**. This replaces the AWS Amplify
flow (`deploy.sh` / `amplify.yml`), which still works if you prefer it.

## Architecture

```
Internet
   │
   ▼
Route53 (optional) ──► ACM cert (TLS)
   │
   ▼
ALB  ◄── AWS Load Balancer Controller  (from k8s Ingress)
   │
   ▼
EKS Service (ClusterIP) ──► Deployment (2+ nginx pods, HPA-scaled)
                                │
                                └── image pulled from ECR
```

- **Container**: `nginx-unprivileged` serving the static HTML on port 8080, as a
  non-root, read-only-rootfs pod. Security headers + cache rules from
  `customHttp.yml` are reproduced in [`nginx/default.conf`](nginx/default.conf).
- **IaC** ([`terraform/`](terraform/)): VPC (3 AZs), EKS cluster + managed node
  group, ECR repo, AWS Load Balancer Controller (IRSA), metrics-server, optional
  ACM cert.
- **Manifests** ([`k8s/`](k8s/)): Namespace, Deployment, Service, ALB Ingress,
  HPA, PodDisruptionBudget.

## Prerequisites

- `aws` CLI (authenticated), `terraform` >= 1.5, `kubectl`, `kustomize`, `docker`, `helm`

## 1. Provision infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit if needed
terraform init
terraform apply
```

Note the outputs: `ecr_repository_url`, `configure_kubectl`, `acm_certificate_arn`.

## 2. Point kubectl at the cluster

```bash
aws eks update-kubeconfig --region us-east-1 --name kadianai-website-eks
```

## 3. Build & push the image

```bash
cd ..
./build-and-push.sh            # tags with the git short SHA + latest
```

## 4. Deploy to the cluster

Edit the image + ACM ARN, then apply. With kustomize:

```bash
cd k8s
kustomize edit set image \
  ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/kadianai-website=<ecr_repository_url>:<tag>
# put your ACM cert ARN into ingress.yaml (certificate-arn annotation)
kubectl apply -k .
```

## 5. Wire up DNS

Get the ALB hostname and point your domain at it:

```bash
kubectl -n kadianai get ingress kadianai-website
```

Create a Route53 **A/ALIAS** (or CNAME) record for `kadianailabs.com` →
the ALB DNS name. If you set `create_acm_certificate = true`, Terraform already
manages the cert; otherwise create/import one in ACM and paste its ARN into the
Ingress annotation.

## Updating the site

```bash
./build-and-push.sh              # new image
kubectl -n kadianai rollout restart deployment/kadianai-website
# or set the new tag via kustomize and `kubectl apply -k k8s/`
```

## Tear down

```bash
kubectl delete -k k8s/           # removes the ALB first (avoids orphaned LB)
cd terraform && terraform destroy
```

> Delete the Ingress/Service **before** `terraform destroy` so the AWS Load
> Balancer Controller cleans up the ALB and target groups it created.

## Cost note

A minimal EKS setup (control plane ~$0.10/hr + 2× t3.small + 1 NAT gateway + ALB)
runs roughly **$120–160/month** — materially more than Amplify for a static site.
EKS is the right call if this site is part of a larger Kubernetes platform; if
it's standalone, Amplify/S3+CloudFront is cheaper. Both paths are kept in-repo.
```
