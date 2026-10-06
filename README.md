# KadianAI LABS

The website deploys exclusively to a single-node K3s cluster through the existing
Azure DevOps build and deploy pipelines. The existing EJS frontend is rendered at
build time and served by non-root nginx; Node is only used for development and CI.
The independent Python API remains in source with its tests, but the website does
not call it and this pipeline does not deploy it.

```text
main → Azure test/build → existing ECR → kubectl → K3s/Traefik → nginx (1 pod)
```

See [DEPLOY-K8S.md](DEPLOY-K8S.md) for bootstrap, TLS, pipeline variables,
registry credential renewal, rollback, migration, and the CAD $10/month guardrail.

Local frontend development:

```bash
cd src/Node
npm ci
npm test
npm start
# Or render the production website into dist/:
APP_VERSION=local npm run build
```

Production image (run from repository root):

```bash
docker build --build-arg APP_VERSION=local -t kadianai-website:local .
docker run --rm --read-only --tmpfs /tmp -p 8080:8080 kadianai-website:local
```

Python API tests:

```bash
python3 -m venv /tmp/kadianai-api-tests
/tmp/kadianai-api-tests/bin/pip install -r src/Python/requirements.txt
/tmp/kadianai-api-tests/bin/python -m pytest src/Python/tests
```
