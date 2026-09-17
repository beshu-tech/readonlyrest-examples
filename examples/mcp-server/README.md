# Elasticsearch MCP Server with ReadonlyREST

Runs the standalone [`elastic/mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch) MCP server against a ReadonlyREST-secured Elasticsearch cluster, authenticating with a plain Elasticsearch API key.

> Kibana's **Agent Builder** MCP endpoint is a Kibana premium feature and out of scope for ROR (ROR secures Elasticsearch and Kibana's HTTP layer, not Kibana's internal plugin APIs). This example uses the standalone, Elasticsearch-only MCP server instead. Note that upstream has marked that server deprecated ("critical security updates only", superseded by Agent Builder) — it still works today and is the only ES-native MCP server ROR can secure.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Docker network (ror-network)                                │
│                                                                │
│  es-ror ─────────────────────────────── kbn-ror               │
│     │                                                          │
│     ├── initializer (one-shot: seeds logs-*, orders-*,        │
│     │                hr-salaries-* indices)                   │
│     │                                                          │
│     ├── mcp-initializer (one-shot: mints an ES API key,       │
│     │                    writes it to the mcp-env volume)     │
│     │                                                          │
│     └── mcp-server (elastic/mcp-server-elasticsearch, :8080)  │
│              ▲                                                 │
│              │ Authorization: ApiKey ... (service identity)   │
│              │ Authorization: Basic ...  (per-user passthrough)│
│           MCP client (Claude Code, curl, ...)                 │
└──────────────────────────────────────────────────────────────┘
```

## Exposed ports

| Service    | Host port | Description                          |
|------------|-----------|---------------------------------------|
| Kibana     | 15601     | ReadonlyREST Kibana UI                |
| MCP server | 18080     | Elasticsearch MCP server (`/mcp`, `/ping`) |

## Users

| Username  | Password  | Role                                                         |
|-----------|-----------|----------------------------------------------------------------|
| `admin`   | `admin`   | Kibana admin; the only identity allowed to mint ES API keys    |
| `analyst` | `analyst` | MCP access to `logs-*` only, via Authorization passthrough     |

## How it works

<details>
<summary>Step 1 — Elasticsearch starts with ReadonlyREST</summary>

Elasticsearch starts with `xpack.security` TLS enabled and the ReadonlyREST plugin loaded. `readonlyrest.yml` defines four ACL blocks:

- **KIBANA** — allows Kibana's internal user (`kibana:kibana`) unrestricted access for its own saved objects and system indices.
- **MCP server (ES API key)** — `token_authentication: {type: api-key}`. ROR asks Elasticsearch to validate the presented `ApiKey <base64 id:api_key>` header; any key ES considers valid is logged in as the single fixed ROR user `mcp`, scoped to `logs-*` / `orders-*` and a read-only action set.
- **Analyst via MCP** — ordinary `auth_key: analyst:analyst` basic auth, scoped to `logs-*` only. This is what per-user access looks like once forwarded through the MCP server (see Step 4).
- **Admins** — `admin:admin`, unrestricted, so it can call `POST /_security/api_key` to mint keys for the MCP server.

</details>

<details>
<summary>Step 2 — Demo data is seeded</summary>

The shared `initializer` container runs `scripts/init.sh`, creating `logs-2026` (50 generated log lines), `orders-2026` (a handful of orders), and `hr-salaries-2026` (salary data). Only the first two match the MCP identity's `indices` pattern — `hr-salaries-2026` is there specifically to prove ROR blocks it.

> The index is named `logs-2026`, not `logs-app-2026` — Elasticsearch ships a built-in `logs-*-*` index template that forces any two-hyphen `logs-`-prefixed name into a data stream, so a plain index create call 400s on a name with two segments after `logs-`.

</details>

<details>
<summary>Step 3 — mcp-initializer mints an API key</summary>

Once Elasticsearch is healthy, `mcp-initializer` calls `POST /_security/api_key` as `admin:admin` (allowed because the Admins block is unrestricted), takes the response's `encoded` field — the ready-to-use `base64(id:api_key)` value — and writes it to a shared Docker volume as `/mcp-env/.env`:

```
ES_URL=https://es-ror:9200
ES_API_KEY=<encoded>
ES_SSL_SKIP_VERIFY=true
```

`ES_SSL_SKIP_VERIFY=true` is used because the MCP server has no custom-CA option — only an on/off switch — and this cluster uses a self-signed certificate.

</details>

<details>
<summary>Step 4 — mcp-server starts</summary>

`mcp-server` runs `docker.elastic.co/mcp/elasticsearch` in `http --container-mode` mode with its working directory pointed at the volume `mcp-initializer` wrote to; the binary's built-in `.env` loader (`dotenvy`) picks up the API key from there automatically. It listens on `:8080` (mapped to host `18080`), exposing `/mcp` (Streamable HTTP, no `initialize` call required first) and `/ping` (health check).

In HTTP mode the server forwards the request's own `Authorization` header to Elasticsearch when present, overriding its configured API key — this is what makes Scenario B below possible.

</details>

## Tool compatibility

All 5 tools tested against the MCP identity (`token_authentication`, scoped to `logs-*`/`orders-*`) and against `hr-salaries-2026` (out of scope). Verified against a live `./run.sh mcp-server` run:

| Tool           | ES request                          | ROR actions required                                                      | In scope (`logs-2026`) | Out of scope (`hr-salaries-2026`) |
|----------------|--------------------------------------|------------------------------------------------------------------------------|--------|--------|
| `list_indices` | `GET /_cat/indices/<pattern>`        | `indices:monitor/stats`, `indices:monitor/settings/get`, `cluster:monitor/state` | ✅ returned, with doc counts | ✅ silently absent — a `logs-*,orders-*,hr-*` pattern only lists `logs-2026` and `orders-2026` |
| `get_mappings` | `GET /<index>/_mapping`              | `indices:admin/mappings/get`                                                 | ✅ mapping returned | ✅ blocked — ES itself returns `index_not_found_exception` (404) |
| `search`       | `POST /<index>/_search`              | `indices:data/read/search`                                                   | ✅ 53 hits | ✅ blocked — same 404 |
| `esql`         | `POST /_query`                       | `indices:data/read/esql` (+ `resolve_fields`, `compute`)                     | ✅ rows returned | ✅ blocked — surfaces as `400 Bad Request` instead (ES|QL validates the `FROM` target differently than the REST index APIs) |
| `get_shards`   | `GET /_cat/shards[/<index>]`         | `cluster:monitor/state`, `indices:monitor/stats`                             | ✅ shards listed | ✅ silently absent |

For every REST-style call above, ROR doesn't hand back a plain 403 for an index outside a user's scope — it rewrites the requested index name to a random string before forwarding to Elasticsearch, so the *client* sees Elasticsearch's own `index_not_found_exception`, not a ROR-branded denial. This is deliberate: it avoids confirming to a caller that a restricted index even exists.

> **Testing blocked calls with `curl`:** this MCP server (`elastic/mcp-server-elasticsearch` 0.4.6) closes its SSE response stream right after a *successful* tool call, but leaves the stream open after an *error* result — the JSON-RPC error itself arrives instantly, but plain `curl` (as used in the smoke test below) keeps waiting for the connection to close and will hang until it hits its own timeout. This is a quirk of the upstream binary, unrelated to ROR — it happens for any ES-level error, ROR-caused or not. Real MCP clients aren't affected, since they resolve on the JSON-RPC `id` rather than on stream closure. If you're poking at a blocked index with `curl` yourself, add `--max-time 5`.

## API keys with ROR — what you get and what you don't

- ROR validates the key **against Elasticsearch** on every request (`ApiKeyService.validateToken`, cached) — it never stores the key itself, so rotating or revoking keys through `_security/api_key` works exactly as it would without ROR. Same mechanism ROR already uses for [Elastic Fleet](https://docs.readonlyrest.com/elasticsearch/fleet).
- **Every valid API key resolves to the same ROR user** (`mcp`, here). An API key is a service identity to ROR, not a per-user identity — you cannot give key A and key B different index permissions with `token_authentication` alone.
- Any `role_descriptors` attached to the key at creation time are not consulted by ROR — ROR does its own authorization from `readonlyrest.yml` and never delegates to Elasticsearch's native security layer once the token is validated.
- For per-user access, run the MCP server in `http` mode (as this example does) and let each client send its own `Authorization` header — ROR sees it as ordinary basic auth or its own API key, unrelated to the server's configured identity. See the `analyst` user below.

## Per-user access (Authorization passthrough)

```bash
claude mcp add --transport http elasticsearch-analyst http://localhost:18080/mcp \
  --header "Authorization: Basic $(printf 'analyst:analyst' | base64)"
```

`analyst` can only see `logs-*` — asking it to list or search `orders-*` or `hr-salaries-2026` is denied by ROR, independently of what the MCP server's own configured API key can reach.

## What to explore

- Ask the agent to list indices, then to search `hr-salaries-2026` directly — both are refused; check `runner/ror-cluster.log` for the ROR audit entries.
- Compare what the `elasticsearch` (service key) and `elasticsearch-analyst` (passthrough) MCP connections can each see.
- Run an ES|QL query (`esql` tool) against `logs-2026` and against `hr-salaries-2026`.

## How to run

```bash
./run.sh mcp-server
```
