# Elasticsearch MCP Server with ReadonlyREST

Runs the standalone [`elastic/mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch) MCP server against a ReadonlyREST-secured Elasticsearch cluster. The MCP server holds **no credentials of its own** — every MCP client sends its own `Authorization` header, the server forwards it to Elasticsearch, and ROR applies that user's ACL block.

> Kibana's **Agent Builder** MCP endpoint is a Kibana premium feature and out of scope for ROR. This example uses the standalone, Elasticsearch-only MCP server instead. Note that upstream has marked that server deprecated ("critical security updates only", superseded by Agent Builder) — it still works today.

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
│     └── mcp-server (elastic/mcp-server-elasticsearch, :8080)  │
│              ▲                                                 │
│              │ Authorization: Basic ... (forwarded unchanged)  │
│           MCP client (Claude Code, curl, ...)                 │
└──────────────────────────────────────────────────────────────┘
```

## Exposed ports

| Service    | Host port | Description                          |
|------------|-----------|---------------------------------------|
| Kibana     | 15601     | ReadonlyREST Kibana UI                |
| MCP server | 18080     | Elasticsearch MCP server (`/mcp`, `/ping`) |

## Users

| Username  | Password  | Role                                                          |
|-----------|-----------|-----------------------------------------------------------------|
| `analyst` | `analyst` | Read-only MCP access to `logs-*` only                           |
| `admin`   | `admin`   | Kibana admin, unrestricted — useful as a contrast through MCP    |

## How it works

<details>
<summary>Step 1 — Elasticsearch starts with ReadonlyREST</summary>

Elasticsearch starts with `xpack.security` TLS enabled and the ReadonlyREST plugin loaded. `readonlyrest.yml` defines three ACL blocks:

- **KIBANA** — allows Kibana's internal user (`kibana:kibana`) unrestricted access for its own saved objects and system indices.
- **Analyst via MCP** — ordinary `auth_key: analyst:analyst` basic auth, scoped to `logs-*` and a read-only action set. Nothing in this block is MCP-specific: it is a plain ROR user, and that is the whole point — the MCP server adds no identity of its own.
- **Admins** — `admin:admin`, unrestricted.

</details>

<details>
<summary>Step 2 — Demo data is seeded</summary>

The shared `initializer` container runs `scripts/init.sh`, creating `logs-2026` (50 generated log lines), `orders-2026` (a handful of orders), and `hr-salaries-2026` (salary data). Only `logs-2026` is inside `analyst`'s `indices` scope — the other two are there to prove ROR blocks them.

> The index is named `logs-2026`, not `logs-app-2026` — Elasticsearch ships a built-in `logs-*-*` index template that forces any two-hyphen `logs-`-prefixed name into a data stream, so a plain index create call 400s on a name with two segments after `logs-`.

</details>

<details>
<summary>Step 3 — mcp-server starts</summary>

Once `initializer` reports healthy (its `/tmp/init_done` healthcheck, which only passes after `init.sh` returns), `mcp-server` runs `docker.elastic.co/mcp/elasticsearch` in `http --container-mode` mode with only two settings: `ES_URL=https://es-ror:9200` and `ES_SSL_SKIP_VERIFY=true` (the MCP server has no custom-CA option, only an on/off switch, and this cluster uses a self-signed certificate). It listens on `:8080` (mapped to host `18080`), exposing `/mcp` (Streamable HTTP, no `initialize` call required first) and `/ping` (health check).

No `ES_API_KEY` or username/password is configured, so in `http` mode the server has nothing to fall back on: it forwards the request's own `Authorization` header to Elasticsearch, and a client that sends none gets a ROR 401.

</details>

## Connect an MCP client

```bash
claude mcp add --transport http elasticsearch-analyst http://localhost:18080/mcp \
  --header "Authorization: Basic $(printf 'analyst:analyst' | base64)"
```

`analyst` can only see `logs-*`. Point a second connection at the same endpoint with `admin:admin` credentials and it sees everything — same server, same tools, different ROR block.

## Tool compatibility

All 5 tools were exercised against a live `./run.sh mcp-server` cluster, in scope (`logs-2026`) and out of scope (`hr-salaries-2026`):

| Tool           | ES request                          | ROR actions required                                                      | In scope (`logs-2026`) | Out of scope (`hr-salaries-2026`) |
|----------------|--------------------------------------|------------------------------------------------------------------------------|--------|--------|
| `list_indices` | `GET /_cat/indices/<pattern>`        | `indices:monitor/stats`, `indices:monitor/settings/get`, `cluster:monitor/state` | ✅ returned, with doc counts | ✅ silently absent — only in-scope indices are listed |
| `get_mappings` | `GET /<index>/_mapping`              | `indices:admin/mappings/get`                                                 | ✅ mapping returned | ✅ blocked — ES itself returns `index_not_found_exception` (404) |
| `search`       | `POST /<index>/_search`              | `indices:data/read/search`                                                   | ✅ 53 hits | ✅ blocked — same 404 |
| `esql`         | `POST /_query`                       | `indices:data/read/esql` (+ `resolve_fields`, `compute`)                     | ✅ rows returned | ✅ blocked — surfaces as `400 Bad Request` instead (ES|QL validates the `FROM` target differently than the REST index APIs) |
| `get_shards`   | `GET /_cat/shards[/<index>]`         | `cluster:monitor/state`, `indices:monitor/stats`                             | ✅ shards listed | ✅ silently absent |

For every REST-style call above, ROR doesn't hand back a plain 403 for an index outside a user's scope — it rewrites the requested index name to a random string before forwarding to Elasticsearch, so the *client* sees Elasticsearch's own `index_not_found_exception`, not a ROR-branded denial. This is deliberate: it avoids confirming to a caller that a restricted index even exists.

> **Testing blocked calls with `curl`:** this MCP server (`elastic/mcp-server-elasticsearch` 0.4.6) closes its SSE response stream right after a *successful* tool call, but leaves the stream open after an *error* result — the JSON-RPC error itself arrives instantly, but plain `curl` (as used in the smoke test below) keeps waiting for the connection to close and will hang until it hits its own timeout. This is a quirk of the upstream binary, unrelated to ROR — it happens for any ES-level error, ROR-caused or not. Real MCP clients aren't affected, since they resolve on the JSON-RPC `id` rather than on stream closure. If you're poking at a blocked index with `curl` yourself, add `--max-time 5`.

## Why no service API key?

The MCP server can also carry a credential of its own (`ES_API_KEY`), and ROR validates such keys with `token_authentication: {type: "api-key"}` — the same mechanism it uses for [Elastic Fleet](https://docs.readonlyrest.com/elasticsearch/fleet). This example deliberately doesn't:

- **Every valid API key resolves to the same ROR user.** An API key is a service identity to ROR, not a per-user identity — you cannot give key A and key B different index permissions with `token_authentication` alone.
- A configured key is also a *fallback*: any client that reaches the MCP port without an `Authorization` header would silently inherit the server's identity. With no key configured, unauthenticated clients get a 401 instead.
- Passthrough keeps ROR's audit log meaningful — each MCP call is attributed to the real user, not to one shared `mcp` account.

## What to explore

- Ask the agent to list indices, then to search `hr-salaries-2026` directly — both are refused; check `runner/ror-cluster.log` for the ROR audit entries.
- Add a second MCP connection with `admin:admin` and compare what each one can see.
- Run an ES|QL query (`esql` tool) against `logs-2026` and against `hr-salaries-2026`.
- Drop the `Authorization` header entirely and watch ROR reject the call with a 401.

## How to run

```bash
./run.sh mcp-server
```
