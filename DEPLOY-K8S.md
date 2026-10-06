# Kubernetes-only website deployment

## Architecture and budget

Azure DevOps remains the CI provider. The build pipeline preserves Node and
Python tests, renders the current EJS landing page (including its version footer),
builds a multi-stage static nginx image, tests it with a read-only filesystem,
and pushes it to an **existing** ECR repository. The deploy pipeline consumes
that build's exact artifact and image reference, applies Kubernetes resources,
and fails if rollout does not complete within 120 seconds. No SSH/docker hosting,
Amplify, managed Kubernetes, or cloud provisioning remains enabled.

The website uses namespace `kadianai-1`, Deployment/Service/Ingress
`kadianai-website`, one nginx replica, requests 10m CPU/32Mi memory and limits
100m CPU/128Mi memory. Its filesystem is read-only with ephemeral writable mounts;
there are no PVCs, HPA, PDB, databases or monitoring stacks. Rollout allows zero
surge pods and one unavailable pod to keep peak website replicas at one. Updates
therefore have a brief outage. A single host also means no node redundancy.
The Python API is independent and unused by this frontend; its source and tests
remain available, but it is not deployed by this website pipeline. An optional
`API_BASE_URL` build argument preserves the existing footer reference if needed.

| Component | Incremental monthly cost assumption (CAD) |
|---|---|
| Existing paid-for host / eligible free-tier host | $0 only if genuinely covered |
| K3s, bundled Traefik, website workload | $0 software fees |
| Existing DNS and free/existing TLS | $0 additional services |
| Existing ECR | $0 target only within existing allowance; storage/transfer can be billed |
| CI | $0 target only within existing Azure DevOps allowance |
| New managed clusters, LB, NAT, disks, DB, extra workers | None provisioned |

**Expected additional infrastructure cost is $0 only under these assumptions.**
The CAD $10 cap is not verified against any live account. Include host CPU/RAM,
root disk, public IP, bandwidth, registry storage/egress, DNS and applicable taxes
in a new host quote. No new paid server is selected or provisioned. If a supported
server cannot fit the full monthly budget, reuse a qualifying existing host or
stop before provisioning; do not undersize K3s or silently exceed the cap.
Prune old registry images with an existing retention policy while retaining enough
image tags for rollback; deleting tags used in Deployment history breaks rollback.

K3s documents a server baseline of 2 CPU cores and 2 GB RAM **before workloads**:
[requirements](https://docs.k3s.io/installation/requirements). Budget headroom for
Traefik, nginx, the OS and any existing host workloads. Use a supported Linux OS
and reliable local disk. This deployment defaults to `linux/amd64`; build for the
host architecture before using an ARM host (a cross-build agent needs emulation).

## Bootstrap an existing, budget-approved host

These are operator commands, not actions run by this repository. Choose a reviewed
K3s release and replace the example variables before running them on the host:

```bash
export K3S_VERSION='<reviewed-supported-K3s-version>'
export K3S_API_HOST='<private-or-restricted-API-hostname>'
curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh
# Review /tmp/install-k3s.sh before executing it.
sudo env INSTALL_K3S_VERSION="$K3S_VERSION" sh /tmp/install-k3s.sh server \
  --tls-san "$K3S_API_HOST" --write-kubeconfig-mode 600 \
  --disable metrics-server --disable local-storage
sudo k3s kubectl get nodes
sudo k3s kubectl apply -f k8s/namespace.yaml
```

Keep bundled Traefik and ServiceLB. K3s's own Traefik Service has type LoadBalancer,
but bundled ServiceLB exposes host ports and creates **no cloud load balancer**.
The website Service remains ClusterIP. Do not install an AWS/cloud LB controller.
See [K3s networking](https://docs.k3s.io/networking/networking-services).
Allow public TCP 80/443 to this node and restrict TCP 6443 to the deployment agent
network/VPN. Do not expose the Kubernetes API to the entire Internet. The CD agent
must be able to reach the kubeconfig endpoint; change its pool to an existing
self-hosted agent if Microsoft-hosted agents cannot reach your private network.
Account for agent hosting costs if it needs a new machine.

Use an operator-issued deployment kubeconfig; keep it outside Git. Prefer an
expiring, namespace-scoped identity and rotate it. The script also applies the
namespace; pre-create it as above and grant only get/patch on namespace
`kadianai-1`, plus the required namespace permissions to manage deployments,
services, ingresses, registry secrets and read pods/replicasets for rollout.
Do not upload the unrestricted server admin kubeconfig for routine CI.
Change the exported config's server endpoint from loopback to the reachable
TLS-SAN hostname without logging credential contents. Set mode 600 and upload it
as Azure DevOps Secure File **website-kubeconfig**, authorizing only this CD pipeline.

## DNS and HTTPS (required before deployment)

Point existing `kadianailabs.com` and `www.kadianailabs.com` DNS records to the
node's reachable public IP. Remove obsolete AAAA records if IPv6 is unavailable.
The Ingress uses Traefik `websecure` and TLS secret `website-tls` in `kadianai-1`.
Do not deploy with an expired, self-signed or default Traefik certificate.

Reuse an existing certificate renewal solution. With certificate files kept
outside the repository, install/update the Secret:

```bash
kubectl -n kadianai-1 create secret tls website-tls \
  --cert=/secure/path/fullchain.pem --key=/secure/path/privkey.pem \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
```

For a new host, a DNS-capable Certbot plugin can obtain free Let's Encrypt TLS
without adding a controller or volume to Kubernetes. For **existing Route53 DNS**
and an existing host IAM role with narrowly scoped DNS challenge permissions,
this Debian/Ubuntu example issues a certificate for both current hosts:

```bash
sudo apt-get install certbot python3-certbot-dns-route53
sudo certbot certonly --dns-route53 --non-interactive --agree-tos \
  --email '<operator-email>' -d kadianailabs.com -d www.kadianailabs.com
```

For other DNS providers use their supported automated DNS plugin and store its
credentials in a root-readable file outside Git. Do not create a new DNS account
or paid zone for this example. Configure a root-owned executable deploy hook at
`/etc/letsencrypt/renewal-hooks/deploy/website-tls`:

```bash
#!/bin/sh
set -eu
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl -n kadianai-1 create secret tls website-tls \
  --cert="$RENEWED_LINEAGE/fullchain.pem" --key="$RENEWED_LINEAGE/privkey.pem" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
```

Run the Secret command once using the initially issued files under
`/etc/letsencrypt/live/kadianailabs.com/`; enable the package's renewal timer and
verify `sudo certbot renew --dry-run`. Validate the hook separately with
`RENEWED_LINEAGE` set to those live certificate files. Traefik reads renewed TLS
Secrets without restarting nginx. Ensure renewal and failure alerts work before
production traffic. No cert-manager is required. If the cluster already has a
Traefik ACME resolver, instead reference that existing resolver through the
Ingress annotation and adapt the TLS preflight check in the script.

The Ingress only exposes HTTPS. If HTTP-to-HTTPS redirection is needed, configure
it once on the existing Traefik web entrypoint through its K3s HelmChartConfig;
do not add a cloud gateway. Avoid editing K3s's generated Traefik manifest.

## Registry pull credentials must remain fresh

Reuse a suitable existing ECR repository (for example `kadianai-frontend` or
`k8s/kadianai-website`). The build's identity needs push access to that repository;
the deploy/host identities only need ECR authorization and pull access. Prefer
existing short-lived service identities. If using Azure secret AWS access keys,
restrict them and rotate them. No ECR repository is created here.

ECR login passwords expire after 12 hours. Deployment refreshes `ecr-pull`, but
future node/pod restarts also need valid pull credentials. On an existing AWS host
with an IAM instance role (or other existing auto-renewing AWS credential source),
install the provided host timer. It adds no Kubernetes workloads:

```bash
# Host needs AWS CLI, Python 3, and kubectl on PATH.
sudo install -d -m 755 /usr/local/lib/website
sudo install -m 755 Devops/scripts/refresh-ecr-secret.sh /usr/local/lib/website/
sudo install -m 644 Devops/scripts/ecr-refresh.service Devops/scripts/ecr-refresh.timer /etc/systemd/system/
# Root-owned config contains ONLY non-secret region/account values:
sudo install -m 600 /dev/null /etc/website-ecr.env
sudo sh -c 'printf "%s\n" "AWS_REGION=us-east-1" "AWS_ACCOUNT_ID=<your-account-id>" > /etc/website-ecr.env'
sudo systemctl daemon-reload
sudo systemctl enable --now ecr-refresh.timer
sudo systemctl start ecr-refresh.service
sudo systemctl status ecr-refresh.timer
```

Replace the account placeholder first. Verify the service succeeds, monitor
failures using existing host alerts, and confirm it continues after reboot.
Credentials are exchanged for a Kubernetes Secret through a temporary mode-600
file; the password never appears in argv or console output. No permanent AWS
keys are included in the unit/config. On a non-AWS host supply an existing secure
credential source or use an existing kubelet ECR credential provider instead.
Do not rely on an expired deployment-time token for production recovery.

## Azure DevOps configuration

Keep the existing pipeline registrations:

- `Devops/build.pipeline.yml` → **build.pipeline**: automatically runs on main.
- `Devops/deploy.pipeline.yml` → existing deploy pipeline: triggers after a
  successful main build and consumes that build's `deploy` artifact. No checkout
  of a newer commit is used. Manual CD runs require explicitly selecting the
  successful main build resource version.
- `Devops/infra.pipeline.yml` remains registered but now fails safely with a
  retirement message and cannot provision infrastructure.

Set variables in **both** build and deploy pipelines (or link the same secured
variable group in each pipeline's UI):

| Setting | Where | Value |
|---|---|---|
| `AWS_REGION` | Both | Existing registry region |
| `AWS_ACCOUNT_ID` | Both | Existing 12-digit registry account |
| `ECR_REPOSITORY` | Build | Existing repository name; no registry hostname |
| `AWS_ACCESS_KEY_ID` | Both, secret | Scoped AWS identity credential |
| `AWS_SECRET_ACCESS_KEY` | Both, secret | Scoped AWS identity credential |
| `imagePlatform` | Build, optional override | `linux/amd64` default |
| `KUBECTL_VERSION` | CD | Exact supported kubectl release matching the K3s Kubernetes minor version |
| `website-kubeconfig` | CD Secure Files | Operator-issued deploy kubeconfig |
| `website-production` | Azure environment | Restrict pipeline access; configure exclusive lock |

For temporary AWS credentials, also map secret `AWS_SESSION_TOKEN` into each AWS
step's environment or use the agent's existing credential provider rather than
static keys. Never put tokens into pipeline YAML. Configure an **exclusive lock**
on `website-production` and `runLatest` behavior to prevent overlapping deployments
and an older build overwriting a newer one. Disable any old classic release,
Amplify auto-build, or SSH deployment defined outside the repository.

## Manual deploy, verification and rollback

From the repository root, with kubeconfig and AWS credentials securely supplied:

```bash
AWS_REGION=us-east-1 AWS_ACCOUNT_ID='<account-id>' \
  ECR_REPOSITORY='<existing-repository>' ./build-and-push.sh
WEBSITE_IMAGE='<registry>/<existing-repository>:<git-sha>' \
  AWS_REGION=us-east-1 AWS_ACCOUNT_ID='<account-id>' ./deploy.sh
```

The script renders the selected image locally before applying, avoiding a failed
placeholder deployment or intermediate rollback revision. It applies Namespace,
Service, Deployment and Ingress without modifying repository manifests. Raw
`kubectl apply -k k8s/` is only a template check until `website:unconfigured` has
been replaced. It is not the production deployment command.

```bash
kubectl -n kadianai-1 get deployment,pods,service,ingress
curl --fail https://kadianailabs.com/health
curl --fail https://www.kadianailabs.com/
kubectl -n kadianai-1 rollout history deployment/kadianai-website
kubectl -n kadianai-1 rollout undo deployment/kadianai-website
kubectl -n kadianai-1 rollout status deployment/kadianai-website --timeout=120s
kubectl -n kadianai-1 logs deployment/kadianai-website
kubectl -n kadianai-1 describe deployment kadianai-website
kubectl -n kadianai-1 get events --sort-by=.lastTimestamp
```

Five Deployment revisions remain available. A rollback still requires its image
in ECR and valid pull credentials. Single-pod outages during deploy are expected.
Use `kubectl top` only if metrics are already available; bootstrap disables metrics
server. No observability stack is installed.

## Migration and retired files

Added: `.dockerignore`, `src/Node/build.js`, registry refresh script and systemd
service/timer. Modified: root Dockerfile, nginx config, build/deploy/infra pipelines,
deploy/build helper scripts, Node package build command, Kubernetes manifests and
local overlay, `.gitignore`, README and this guide. Removed: old runtime Node
Dockerfile, HPA/PDB, paid EKS/ALB/NAT Terraform configuration and EC2 CloudFormation
template. Source applications and existing test suites are retained.

**Removing these files does not stop existing cloud charges.** No live resources
have been inspected or deleted. Before switching DNS, validate the new HTTPS site
and obtain an inventory of any old Amplify app, EC2 host, EKS nodes/control plane,
ALB, NAT gateway, volumes and public IPs. Disable their old deployments outside Git.
After a verified cutover, decommission only resources known to belong exclusively
to the old website. If old Terraform infrastructure exists, recover its previous
configuration from Git and use its securely stored state to plan cleanup; never
remove state or destroy shared registry/DNS resources blindly. Existing standalone
Docker services on the reused host may own ports 80/443: schedule their retirement
before K3s Traefik starts. Do not stop a backend still used by other clients.

## Validation limitations

CI includes source tests, production build, nginx config validation and container
smoke tests before pushing. Deployment verifies rollout and returns nonzero on
failure. Operator acceptance also requires a reachable cluster, valid TLS,
registry access, DNS cutover and confirmed account costs. Repository checks alone
cannot prove live rollout, cert renewal, or the monthly bill.

Local implementation verification passed: three frontend tests, four API tests,
static render/asset equivalence, YAML and embedded shell parsing, strict Kubernetes
1.34 schemas for both Kustomize builds, manifest wiring and single-replica guardrails,
and simulated deployment failure propagation. The Docker image built successfully
and passed runtime checks with UID 101, read-only root, dropped capabilities,
128Mi memory and 100m CPU limits: nginx configuration, page/version, both health
endpoints, 404, asset headers and absence of Node/runtime dependencies. These checks
did not push images, run Azure pipelines, provision infrastructure or deploy to a
live cluster. Existing Node dependencies reported npm audit findings during the
build; they are build/development dependencies and are not shipped in nginx.
