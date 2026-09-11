# Selco `core-dev` + `backbone-dev` — Docker Compose rendition

Generated from the live EKS cluster `new-selco-dev` (namespaces `core-dev` and
`backbone-dev`) to test whether the dev environment can move off Kubernetes
to Docker Compose to cut cost. All images, env vars, health checks, and DB
migration steps are taken directly from the running deployments — this is
not a from-scratch rebuild.

## What's in here vs. what was left out

**Included (44 services, ~24.4 GiB memory budget):**
- All 34 core-dev application microservices (gateway, egov-* services,
  im-services, field-planner, facility-service, translator, etc.) plus
  `digit-ui`.
- `elasticsearch`, `kafka`, `redis`, `kafka-ui`, `kibana-kibana`, `pgadmin4`,
  `playground` from backbone-dev.
- 22 one-shot `*-migrate` Flyway jobs (mirrors each service's k8s
  `db-migration` initContainer, run against the same RDS instance).
- `jaeger-tracing-collector` / `jaeger-tracing-query`, behind the
  `observability` Compose profile (see below) since they're not started by
  default — the live jaeger pods in `backbone-dev` are currently `0/1
  Ready` (not actually serving), so this is best-effort parity, not a
  faithfully working feature.

**Deliberately excluded**, per your answers when this was scoped:
- 10 of 11 state-specific UI deployments (`assam`, `gujarat`, `maharashtra`,
  `manipur`, `meghalaya`, `mizoram`, `nagaland`, `odisha`, `sikkim`,
  `installation-qc`) — only `digit-ui` is included.
- Kubernetes-native infra with no Compose equivalent: `cert-manager` (+
  cainjector/webhook), `ingress-nginx-controller`, and the JupyterHub
  `hub`/`proxy`/`user-scheduler` trio.
- Postgres itself — you're keeping RDS, so no local Postgres container.

**Collapsed for cost/resource reasons:**
- Elasticsearch: 2 StatefulSets × 3 replicas (6 pods, ~9GB requested) →
  1 single-node container (`discovery.type=single-node`, xpack security
  **enabled** with the `elastic` superuser password from `.env` — no TLS
  locally, unlike the source cluster which also does mutual TLS). Network
  aliases `elasticsearch-data` and `elasticsearch-master` both resolve to it.
- Kafka: 3-node KRaft StatefulSet → 1 single-node KRaft broker. Aliases
  `kafka-kraft-controller`, `kafka-kraft-controller-headless`, `kafka-kraft`
  all resolve to it.

## Prerequisites

- Docker + Docker Compose v2.
- Registry access to `selcohub/*` and `egovio/*` images (`docker login` if
  these are private) — the compose file references the **exact tags**
  currently running in `core-dev`/`backbone-dev`, unpinned to `latest`.
- Network reachability from wherever you run this to the RDS instance in
  `.env` (`DB_HOST`) — VPN / security group access, same as your laptop
  already needs for `kubectl` today.
- ~8 vCPU / 32GB host. Planned memory limits sum to ~24.4 GiB, leaving
  headroom for the Docker daemon and host OS. CPU limits intentionally sum
  above 8 vCPU (standard Compose practice — they're throttles, not
  reservations like k8s `requests`; most of these services are idle most of
  the time).

## Setup

```bash
cp .env.example .env
# Fill in DB_USERNAME / DB_PASSWORD (the shared RDS creds) and any of the
# other secrets you need (SMS/mail provider creds, Google Maps key, Gemini
# key, S3 keys for filestore, egov-enc-service master key/salt/IV).
# DB_HOST/DB_NAME are already filled in with the real RDS endpoint/db name
# used by core-dev today — that's not a credential, just an address.

docker compose up -d elasticsearch kafka redis   # bring up the data layer first
docker compose up -d                             # then everything else
```

Migration jobs (`*-migrate`) run automatically before their service starts
(`depends_on: condition: service_completed_successfully`) — they run Flyway
against the **same RDS schema** the live k8s cluster already uses, so they
should no-op (nothing new to migrate) rather than change anything.

Gateway is reachable at `http://localhost:18024/`, routed via a **static**
copy of the routes.properties fetched from the live gateway pod (see
"Known limitations" below). Each service is also directly reachable on its
own host port — see the table below.

## Data migration (Elasticsearch / Kafka)

Since backbone-dev's data stores are being collapsed to single-node, two
scripts are included to pull the actual data across rather than starting
from empty:

- `scripts/migrate-elasticsearch.sh` — port-forwards to the live
  `elasticsearch-master` service, pulls the `ELASTIC_PASSWORD` secret at
  runtime (never written to disk), and uses `elasticdump` (via `npx`, no
  install needed) to copy mappings + data for every non-system index into
  the local compose Elasticsearch. Pass specific index names as args to
  migrate a subset.
- `scripts/migrate-kafka-topics.sh` — recreates every topic (name +
  partition count, replication factor forced to 1) from the live
  `kafka-kraft-controller` StatefulSet onto the local Kafka. This copies
  **topic definitions, not historical messages** — in this platform Kafka
  is a transient bus (persister → Postgres, indexer → Elasticsearch are the
  durable stores), so consumers rebuild state without needing Kafka
  history. The script prints a `kcat` one-liner at the end if you do need
  to replay a specific topic's messages.

Run these after `docker compose up -d elasticsearch kafka` and before
bringing up the app services, so persister/indexer find the indices/topics
already in place.

## Config files pulled from `Selco-Foundation/configs`

`egov-persister`, `egov-indexer`, and `pdf-service` load their YAML/JSON
rule files from a git-synced volume in k8s (`git-sync` initContainer against
`github.com/Selco-Foundation/configs`, mixing the `main` and
`add_project_indexer` branches per service). Since Compose has no
equivalent of that init-container-plus-SSH-deploy-key pattern, the exact
38 files each service actually references (per their
`EGOV_PERSIST_YML_REPO_PATH` / `EGOV_INDEXER_YML_REPO_PATH` /
`DATA_CONFIG_URLS` / `FORMAT_CONFIG_URLS` env vars) were copied once into
`configs/` in this repo, preserving the same relative paths the containers
expect (mounted read-only). If that upstream repo changes, re-run the same
copy step manually — there's no live sync here.

`audit-service` also has a `git-sync` initContainer in k8s, but nothing in
its env references a synced file, so it was left out — it doesn't appear to
use it.

## Known limitations / where this differs from k8s

- **Gateway routing is static.** In k8s, an initContainer
  (`gateway-kubernetes-discovery`) queries the K8s API at pod startup to
  generate `/etc/zuul/routes.properties`. Compose has no K8s API to query,
  so `configs/gateway/routes.properties` is a **snapshot** of what that
  initContainer produced on 2026-09-09, with `.core-dev` stripped from each
  URI. If new services get routes added in k8s later, this file needs a
  manual refresh (re-run `kubectl exec <gateway-pod> -c gateway -- cat
  /etc/zuul/routes.properties` and strip `.core-dev`).
- **Elasticsearch has auth but no TLS locally.** The source cluster runs
  xpack security + mutual TLS between nodes; this single-node container
  enables xpack security (login required, password in `.env`) but serves
  plain HTTP, not HTTPS — acceptable as long as the ES/Kibana ports stay
  off the public internet, but not equivalent to the source cluster's
  posture from a security-testing standpoint.
- **Jaeger is off by default** (`--profile observability` to include it) —
  see above, the source pods aren't actually healthy right now either.
- **No image is rebuilt from source** — this only reproduces the deployed
  *runtime* config. If your goal is inner-dev-loop (edit code, see it
  running), you'd still build/push images the same way you do for k8s and
  update the tag in `docker-compose.yml`, or bind-mount build output.

## Service ports (host → container)

| Service | URL |
|---|---|
| gateway | http://localhost:18024 |
| digit-ui | http://localhost:18004 |
| egov-mdms-service | http://localhost:18013 |
| egov-user | http://localhost:18018 |
| ... | (34 app services total, sequential from 18000 — see `docker-compose.yml`) |
| elasticsearch | http://localhost:19200 |
| kafka | localhost:19092 |
| redis | localhost:16379 |
| kafka-ui | http://localhost:18300/kafka-ui |
| kibana | http://localhost:15601/kibana |
| pgadmin4 | http://localhost:15050/pgadmin4 |
| playground | http://localhost:18400 |

## Resource sizing rationale

k8s `requests.memory` were used as the starting point, then trimmed (large
outliers like `im-services`/`processor-services` 2Gi→1Gi,
`egov-mdms-service` 1.8Gi→1.5Gi, `egov-filestore` 1.5Gi→1Gi, etc.) to leave
headroom on an 8 vCPU/32GB box, and filled in for the handful of services
that had no k8s memory limit set at all (`digit-ui`, `pdf-service`,
`ingestion-service`, `redis`, `pgadmin4`, `playground`, jaeger). CPU limits
are assigned per service tier (heavy: ES/Kafka/Kibana/mdms/gateway ≈
0.5–1.5 vCPU; standard Java microservice ≈ 0.25–0.3 vCPU; static/UI ≈
0.1–0.2 vCPU) and intentionally sum above 8 vCPU — see Prerequisites.

If 32GB proves tight in practice, the biggest levers are `elasticsearch`
(2GB), `kafka` (1GB), `egov-mdms-service` (1.5GB), and `im-services`/
`processor-services` (1GB each).
