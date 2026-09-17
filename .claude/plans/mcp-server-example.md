# Plan: `examples/mcp-server` — Elasticsearch MCP Server behind ReadonlyREST

**Audience:** the implementation agent. Everything below was verified against the actual sources
(ROR core Scala, elastic/mcp-server-elasticsearch Rust, ROR docs, this repo's runner) on 2026-09-17.
Where something could not be verified without running the stack, it is marked **VERIFY**.

**Goal:** a runnable example (`./run.sh mcp-server`) proving that the Elasticsearch MCP server works
against a ROR-secured cluster with **Elasticsearch API-key authentication**, plus a README that
answers the customer question honestly, including the limitations.

---

## 1. Background / why this shape

The customer (Zdenek) asked about the **Kibana Agent Builder MCP endpoint**. That is a Kibana
premium feature, so ROR cannot support it — say so once in the README and move on. The plan targets
[`elastic/mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch), which talks
to **Elasticsearch only** and therefore sits entirely behind ROR's ACL.

Note for the README: that server carries an upstream deprecation notice ("critical security updates
only", superseded by Agent Builder). It still works and is the only ES-native MCP server that ROR can
secure today. State this plainly rather than hiding it.

## 2. Verified facts about the MCP server (v0.4.6, Rust)

| Fact | Source |
|---|---|
| Image `docker.elastic.co/mcp/elasticsearch`, multi-arch, entrypoint `/usr/local/bin/elasticsearch-core-mcp-server`, base `cgr.dev/chainguard/wolfi-base` | `Dockerfile` |
| Subcommands: `stdio` and `http`. HTTP listens on `:8080`, MCP endpoint `/mcp`, health `/ping` | `README.md`, `src/cli.rs` |
| Args can also come from the `CLI_ARGS` env var (whitespace-split) | `src/bin/elasticsearch-core-mcp-server.rs` |
| Config env: `ES_URL`, `ES_API_KEY`, `ES_USERNAME`/`ES_PASSWORD`, `ES_SSL_SKIP_VERIFY` | `elastic-mcp.json5`, `README.md` |
| **Reads a `.env` file** at startup via `dotenvy::dotenv()` (searches CWD upwards). Real env vars take precedence over `.env`. | `src/bin/elasticsearch-core-mcp-server.rs` |
| **In `http` mode the incoming `Authorization` header is forwarded to ES per request**, overriding the configured credentials. Accepts `ApiKey …`, `Basic …`, and strips a leading `Bearer ` prefix. | `src/servers/elasticsearch/mod.rs:81-103` |
| No custom-CA option — only `ES_SSL_SKIP_VERIFY=true` | `src/servers/elasticsearch/mod.rs` |
| 5 tools and the ES calls they make | `src/servers/elasticsearch/base_tools.rs` |

Tool → ES request → ES action string:

| Tool | Request | Action |
|---|---|---|
| `list_indices` | `GET /_cat/indices/<pattern>?format=json&h=index,status,docs.count` | `indices:monitor/stats`, `indices:monitor/settings/get`, `cluster:monitor/state` |
| `get_mappings` | `GET /<index>/_mapping` | `indices:admin/mappings/get` |
| `search` | `POST /<index>/_search` | `indices:data/read/search` |
| `esql` | `POST /_query` | `indices:data/read/esql` (+ `…/resolve_fields`, `…/compute`) |
| `get_shards` | `GET /_cat/shards[/<index>]?format=json` | `cluster:monitor/state`, `indices:monitor/stats` |

## 3. Verified facts about ROR + API keys

- `token_authentication` with `type: "api-key"` asks **Elasticsearch** to validate the key
  (`ApiKeyService.validateToken`, result cached) and, on success, logs the request in as the
  **single fixed `username` from the config**
  (`core/.../blocks/rules/auth/TokenAuthenticationRule.scala`).
- The header prefix is **strictly `ApiKey`** (case-insensitive), header name defaults to
  `Authorization`, overridable with `header:`
  (`core/.../factory/decoders/rules/auth/TokenAuthenticationRuleDecoder.scala`,
  `AuthorizationTokenPrefix.api = "ApiKey"`). This matches exactly what the MCP server sends.
- Requires ES ≥ 7.14 and `xpack.security.enabled: true` with HTTP TLS (API key service).
  ROR ≥ **1.69.0** (that release added Fleet/API-key/service-token support).
- **Key limitation to document:** every valid ES API key maps to the *same* ROR user, so you cannot
  give key A and key B different index permissions with `token_authentication` alone. API keys are a
  *service identity*, not a per-user identity. Per-user ACLs need basic-auth passthrough
  (see §5, scenario B) or one MCP server process per identity.
- ROR applies the ACL to ES|QL (1.71.0 also covers `LOOKUP JOIN`), and treats `/_cat/indices` as an
  index-aware path (filtered by the `indices` rule, `PathValue.isCatIndicesPath`). `/_cat/shards`
  has **no** special handling in ROR core → **VERIFY** what it returns for a restricted user, and
  write the result in the README compatibility table.

## 4. Deliverable: files to create

```
examples/mcp-server/
  .env                              # versions + ROR_MIN_LICENSE_EDITION=FREE
  README.md                         # title + first paragraph are printed by run.sh
  confs/elasticsearch.yml           # copy of examples/fleet/confs/elasticsearch.yml (xpack security + TLS)
  confs/kibana.yml                  # copy of examples/basic-multitenancy/confs/kibana.yml
  confs/readonlyrest.yml            # see §5
  docker-compose.override.yml       # mcp-initializer + mcp-server services
  images/mcp-initializer/
    Dockerfile                      # FROM ubuntu:24.04 + curl + jq (mirror examples/fleet/images/fleet-initializer)
    entrypoint.sh                   # creates API keys, writes /mcp-env/.env
  scripts/init.sh                   # seed demo indices (runs in the shared `initializer` container)
  scripts/post-start.sh             # print endpoints, users, and the `claude mcp add` one-liner
```

Do **not** add a `certs/` dir: the runner's ES/KBN images already bake in `ca.crt`/`elasticsearch.crt`
(`runner/images/es/Dockerfile-API`). The MCP server uses `ES_SSL_SKIP_VERIFY=true` because it has no
custom-CA option.

Remember to add the example to the table in the root `README.md`.

## 5. `confs/readonlyrest.yml` (starting point)

```yaml
readonlyrest:

  audit:
    enabled: true
    outputs: [index]

  access_control_rules:

    - name: "KIBANA"
      type: allow
      auth_key: kibana:kibana
      verbosity: error

    # Scenario A — the MCP server's own service identity.
    # ROR asks ES to validate the API key; any valid key resolves to username "mcp".
    - name: "MCP server (ES API key)"
      type: allow
      token_authentication:
        type: "api-key"
        username: "mcp"
      indices: ["logs-*", "orders-*"]
      actions:
        - "indices:data/read/*"
        - "indices:admin/mappings/get"
        - "indices:monitor/*"
        - "cluster:monitor/*"

    # Scenario B — per-user identity via Authorization passthrough (http mode).
    - name: "Analyst via MCP"
      type: allow
      auth_key: analyst:analyst
      indices: ["logs-*"]
      actions:
        - "indices:data/read/*"
        - "indices:admin/mappings/get"
        - "indices:monitor/*"
        - "cluster:monitor/*"

    - name: "Admins"
      type: allow
      auth_key: admin:admin
      kibana:
        access: admin
```

Notes:
- **Do not copy the fleet example's `forbid` block for `cluster:admin/xpack/security/api_key/*`** —
  the initializer needs `POST /_security/api_key`. If you want to show the forbid pattern, put it
  *below* the Admins block so admin can still mint keys, and say why in the README.
- The `actions` allow-list is what makes the MCP identity genuinely read-only. Tune it against real
  ACL log output (`runner/ror-cluster.log`) — start permissive, then tighten, then re-run all 5 tools.
- Scenario B is what answers "can different agents see different data?" — it works because ROR sees
  ordinary basic auth. Two personas (`analyst`, `admin`) are enough; do not build a full multitenancy
  demo here (that is `basic-multitenancy`, and it needs an ENT license).

## 6. `docker-compose.override.yml` (starting point)

```yaml
services:

  mcp-initializer:
    build:
      context: ${EXAMPLE_DIR}/images/mcp-initializer
      dockerfile: Dockerfile
    hostname: mcp-initializer
    depends_on:
      es-ror:
        condition: service_healthy
    volumes:
      - mcp-env:/mcp-env
    networks:
      - ror-network

  mcp-server:
    image: docker.elastic.co/mcp/elasticsearch:${MCP_SERVER_VERSION:-0.4.6}
    hostname: mcp-server
    command: ["http"]
    working_dir: /mcp-env          # dotenvy picks up /mcp-env/.env written by the initializer
    depends_on:
      mcp-initializer:
        condition: service_completed_successfully
    ports:
      - "18080:8080"
    volumes:
      - mcp-env:/mcp-env:ro
    networks:
      - ror-network
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8080/ping | grep -q pong"]
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 20s

volumes:
  mcp-env:
```

**Risks + fallbacks, in order of preference:**

1. `working_dir` + `/mcp-env/.env` is the cleanest way to inject a *runtime-generated* API key
   (the key value only exists after ES is up). **VERIFY** that dotenvy actually finds it; the image
   has no `WORKDIR`, and `dotenv()` walks up from the CWD.
2. If that fails: build a thin wrapper image
   `FROM docker.elastic.co/mcp/elasticsearch:0.4.6`, add an entrypoint shell script that reads
   `/mcp-env/api-key`, exports `ES_API_KEY`, and `exec`s the binary — same pattern as
   `examples/fleet/images/apm-agent/entrypoint.sh`. wolfi-base ships a shell.
3. If the healthcheck binary is missing in wolfi-base (no `curl`/`wget`), drop the healthcheck and
   use `depends_on: service_started`, or healthcheck `mcp-server` from the initializer instead.

Also **VERIFY**: `docker compose up --wait` (see `runner/run.sh`) tolerates the one-shot
`mcp-initializer`. The fleet example does the same thing, so it should be fine.

## 7. `images/mcp-initializer/entrypoint.sh` — what it must do

Model it on `examples/fleet/images/fleet-initializer/entrypoint.sh` (same `check_curl` wrapper,
same wait-loop, `#!/bin/bash -x`, fail loudly).

1. Wait until `https://es-ror:9200/_cluster/health` answers as `admin:admin`.
2. Create the service API key:
   `POST /_security/api_key -d '{"name":"mcp-server"}'` → take the **`encoded`** field (that is the
   base64 `id:api_key` value the `ApiKey` scheme needs; if a build returns only `id`/`api_key`,
   compute `base64(id:api_key)` yourself).
3. Write `/mcp-env/.env`:
   ```
   ES_URL=https://es-ror:9200
   ES_API_KEY=<encoded>
   ES_SSL_SKIP_VERIFY=true
   ```
4. Also write the raw key to `/mcp-env/api-key` and echo it to stdout so `post-start.sh` and the
   README's curl examples can use it.
5. Exit 0 (one-shot).

**VERIFY while implementing:** that `POST /_security/api_key` actually succeeds through ROR as
`admin:admin`. ROR forwards it to ES and ES owns the key. The ROR Fleet guide documents Fleet Server
doing exactly this, so it should work; if it does not, fall back to creating the key via the
`kibana:kibana` block and note it.

**Open question worth answering for the customer (cheap to test here):** create a second key with
restrictive `role_descriptors` and check whether ES enforces them under ROR. Expectation: **no** —
ROR does its own authorization and runs the request internally, so the key's privileges are ignored
and only the ROR block's `indices`/`actions` apply. Confirm and write the answer in the README.

## 8. `scripts/init.sh`

Runs in the shared `initializer` container (`ELASTICSEARCH_USER=kibana` by default, helpers in
`/usr/local/lib/ror-utils.sh`). Seed enough data that the tools return something interesting:

```bash
source /usr/local/lib/ror-utils.sh
createIndex "logs-app-2026"     && generate_log_documents 50 | putDocument "logs-app-2026"
createIndex "orders-2026"       && putDocument "orders-2026" '{...}'   # a few hand-written docs
createIndex "hr-salaries-2026"  && putDocument "hr-salaries-2026" '{...}'  # NOT in the MCP block → proves the ACL
```

`hr-salaries-*` is the money shot: ask the agent "list all indices" / "search hr-salaries" and it
cannot see it. Make the README call that out.

## 9. `scripts/post-start.sh`

Print, in this order:
1. Kibana URL `https://localhost:15601` and the users (`admin:admin`, `analyst:analyst`).
2. MCP endpoint `http://localhost:18080/mcp`, health `http://localhost:18080/ping`.
3. The exact wiring command for Claude Code:
   `claude mcp add --transport http elasticsearch http://localhost:18080/mcp`
   and the per-user variant that exercises passthrough:
   `claude mcp add --transport http elasticsearch-analyst http://localhost:18080/mcp --header "Authorization: Basic $(printf 'analyst:analyst' | base64)"`
4. A copy-paste `curl` that lists tools, so the example can be checked without any MCP client:
   ```bash
   curl -s http://localhost:18080/mcp -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
   ```
   **VERIFY** the streamable-HTTP handshake actually accepts a bare `tools/list` without an
   `initialize` first; if not, ship a tiny `scripts/mcp-smoke-test.sh` that does
   `initialize` → `tools/list` → `tools/call list_indices` instead. That script is the example's
   self-test and the thing to run in CI/by hand.

Follow the existing convention: `open https://localhost:15601` at the end.

## 10. README.md for the example

Mirror the fleet README's shape: `# Title`, one description paragraph (both are printed by
`run.sh`), architecture box, ports table, users table, `<details>` step-by-step, "What to explore",
"How to run". Then add three sections that are specific to this example:

1. **Tool compatibility table** — the 5 tools × (works / blocked / filtered) with the ROR actions
   involved. Fill it from real runs, not from this plan.
2. **API keys with ROR — what you get and what you don't**: ROR validates keys against ES, never
   stores them, so rotation is free; but all keys collapse to one ROR username, and any
   `role_descriptors` on the key are (**VERIFY**) not enforced. Point at
   https://docs.readonlyrest.com/elasticsearch/fleet for the same mechanism under Fleet.
3. **Per-user access** — the `Authorization` passthrough trick, with the `analyst` demo.

Also state up front: Kibana Agent Builder's MCP endpoint is a Kibana premium feature and is out of
scope; this example uses the standalone Elasticsearch MCP server, which is upstream-deprecated.

## 11. `.env`

```
ROR_MIN_LICENSE_EDITION=FREE

ES_VERSION=9.3.3
ROR_ES_PLUGIN_SOURCE=API
ROR_ES_VERSION=1.69.1

KBN_VERSION=9.3.3
ROR_KBN_PLUGIN_SOURCE=API
ROR_KBN_VERSION=1.69.1

MCP_SERVER_VERSION=0.4.6
```

Keep the same ES/ROR pins as the other examples (proven combination). ROR must be ≥ 1.69.0 for
`token_authentication: api-key`. FREE edition is enough — do not use Kibana multitenancy here.

## 12. Definition of done

1. `./run.sh mcp-server` comes up clean from scratch (`./clean.sh` first), no manual steps.
2. `curl http://localhost:18080/ping` → `pong`.
3. All 5 MCP tools exercised against the ROR-secured cluster; results recorded in the README table.
4. `hr-salaries-2026` is provably invisible to the MCP identity (both `list_indices` and a direct
   `search`), and the denial shows up in the ROR audit index / `runner/ror-cluster.log`.
5. The `analyst` passthrough path returns a different index set than the service key path.
6. Root `README.md` example table updated.
7. README answers, in plain language: *does it work with ROR* (yes, with API keys), *what is not
   supported* (Agent Builder; per-key ACL differentiation), *what was tested* (versions + table).

## 13. Suggested reply to the customer (draft, for the human to send)

- Agent Builder's MCP endpoint is a Kibana premium feature → not supportable with ROR.
- The standalone `elastic/mcp-server-elasticsearch` works with ROR: it authenticates with a normal ES
  API key, and ROR validates that key through Elasticsearch (`token_authentication: type: api-key`),
  the same mechanism we already ship for Elastic Fleet.
- Caveat: with ROR, an API key is a service identity — every valid key resolves to one ROR user, so
  permissions come from the ROR block, not from the key's `role_descriptors`. For per-user access,
  run the MCP server in HTTP mode and let each client pass its own `Authorization` header.
- We now ship a runnable example: `curl -sL …/quickstart.sh | bash -s mcp-server` (link the example
  dir), including a table of which MCP tools work and which ROR rules they need.
