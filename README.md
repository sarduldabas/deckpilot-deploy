# deckpilot-deploy

Environment repo: everything shared by the services. See the top-level `README.md` of the project for the full run guide.

| Path | Purpose |
|---|---|
| `k8s/namespace.yaml`, `k8s/configmap.yaml` | `deckpilot` namespace and shared config (`LLM_PROVIDER`, service URLs) |
| `docker-compose.yml` | run everything locally without Kubernetes |
| `scripts/build-images.ps1` | build the 5 images inside minikube's Docker daemon |
| `scripts/create-secrets.ps1` | create `postgres-secret` (random password) |
| `scripts/deploy.ps1` | apply namespace, config, secrets and every service's `k8s/` folder |
| `.env.example` | **the one config file**: mode, endpoint, key, model, reasoning level, per-agent models, research depth, theme, timeouts. Copy to `.env` (git-ignored) |
| `scripts/sync-config.ps1` | push `.env` into the cluster (ConfigMap + `azure-openai` Secret) and restart the services |
| `scripts/use-mode.ps1` | switch agents between `mock` and `azure` (edits `.env`, then syncs) |
| `scripts/push-all.ps1` | create GitHub repos and push all six folders |
| `postman/DeckPilot.postman_collection.json` | requests for every endpoint |

Each service keeps its own `k8s/` manifests in its own repo, so it can be deployed independently
(`kubectl apply -f <service>/k8s`). Secrets are never stored in any repo.

## Changing the model, reasoning level or key
Edit `.env`, nothing else.
```powershell
Copy-Item .env.example .env        # first time only, then fill in endpoint, key and deployment
# edit .env: AZURE_OPENAI_DEPLOYMENT, LLM_REASONING_EFFORT, BUILDER_REASONING_EFFORT, AZURE_OPENAI_API_KEY ...
docker compose up -d               # Docker Compose
.\scripts\sync-config.ps1           # Kubernetes (updates ConfigMap + Secret and restarts the four deployments)
```
Quality vs cost: `MAX_QUERIES` (research depth) and `BUILDER_REASONING_EFFORT` (`low` / `medium` / `high`) are the two
knobs that matter. `BUILDER_MODEL` lets the builder use a stronger deployment than the other agents.
An invalid value (for example a reasoning level the model rejects) appears in the project's Activity list.
