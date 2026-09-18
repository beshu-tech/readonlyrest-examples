# Elasticsearch MCP Server with ReadonlyREST

Runs the standalone [`elastic/mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch) MCP server against a ReadonlyREST-secured Elasticsearch cluster. The MCP server holds **no credentials of its own** — every MCP client sends its own `Authorization` header, the server forwards it to Elasticsearch, and ROR applies that user's ACL block.

> Kibana's **Agent Builder** MCP endpoint is a Kibana premium feature and out of scope for ROR. This example uses the standalone, Elasticsearch-only MCP server instead. Note that upstream has marked that server deprecated ("critical security updates only", superseded by Agent Builder) — it still works today.

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Docker network (ror-network)                                  │
│                                                                │
│  es-ror ─────────────────────────────── kbn-ror                │
│     │                                                          │
│     ├── initializer (one-shot: seeds logs-*, orders-*,         │
│     │                hr-salaries-* indices)                    │
│     │                                                          │
│     └── mcp-server (elastic/mcp-server-elasticsearch, :8080)   │
│              ▲                                                 │
│              │ Authorization: Basic ... (forwarded unchanged)  │
│              ├── opencode-analyst   sends analyst:analyst      │
│              ├── opencode-hr        sends hr:hr                │
│              │                                                 │
└──────────────┼─────────────────────────────────────────────────┘
               │
            MCP client on the host (any MCP client, curl, ...)
```

## Exposed ports

| Service    | Host port | Description                          |
|------------|-----------|---------------------------------------|
| Kibana     | 15601     | ReadonlyREST Kibana UI                |
| MCP server | 18080     | Elasticsearch MCP server (`/mcp`, `/ping`) |
| opencode   | 1455      | OAuth redirect target for browser sign-ins inside `opencode-analyst` |

## Users

| Username  | Password  | Reaches                                                         |
|-----------|-----------|-----------------------------------------------------------------|
| `analyst` | `analyst` | `logs-*` and `orders-*`, through MCP and in Kibana (read-only)   |
| `hr`      | `hr`      | `hr-salaries-*` and `orders-*`, same access in both             |
| `admin`   | `admin`   | Kibana admin, unrestricted - useful as a contrast through MCP   |

`orders-*` is the shared ground; each user also has one index pattern the other cannot see at all — in Kibana's Discover exactly as through an MCP tool call, since it is one ACL either way.

## How it works

<details>
<summary>Step 1 — Elasticsearch starts with ReadonlyREST</summary>

Elasticsearch starts with `xpack.security` TLS enabled and the ReadonlyREST plugin loaded. `readonlyrest.yml` defines three ACL blocks:

- **KIBANA** — allows Kibana's internal user (`kibana:kibana`) unrestricted access for its own saved objects and system indices.
- **Logs analyst via MCP** — ordinary `auth_key: analyst:analyst` basic auth, scoped to `logs-*` + `orders-*` with `kibana: {access: ro}`.
- **HR analyst via MCP** — the same shape with `auth_key: hr:hr`, scoped to `hr-salaries-*` + `orders-*`. Nothing in either block is MCP-specific: they are plain ROR users who can equally log into Kibana, and that is the whole point — the MCP server adds no identity of its own.

  `kibana: {access: ro}` does the work an explicit `actions:` list used to: it admits the read-only action set (which covers all five MCP tools) plus the Kibana-internal calls a browser session needs, and refuses writes — a saved-object `POST` as `analyst` comes back `403 Forbidden by ReadonlyREST`. An explicit `actions:` list instead of it would let the MCP tools through but leave Kibana unusable.
- **Admins** — `admin:admin`, unrestricted.

</details>

<details>
<summary>Step 2 — Demo data is seeded</summary>

The shared `initializer` container runs `scripts/init.sh`, creating `logs-2026` (50 generated log lines), `orders-2026` (a handful of orders), and `hr-salaries-2026` (salary data). `logs-2026` belongs to `analyst`, `hr-salaries-2026` to `hr`, and `orders-2026` to both — so the same MCP server answers two agents differently.

> The index is named `logs-2026`, not `logs-app-2026` — Elasticsearch ships a built-in `logs-*-*` index template that forces any two-hyphen `logs-`-prefixed name into a data stream, so a plain index create call 400s on a name with two segments after `logs-`.

</details>

<details>
<summary>Step 3 — mcp-server starts</summary>

Once `initializer` reports healthy (its `/tmp/init_done` healthcheck, which only passes after `init.sh` returns), `mcp-server` runs `docker.elastic.co/mcp/elasticsearch` in `http --container-mode` mode with only two settings: `ES_URL=https://es-ror:9200` and `ES_SSL_SKIP_VERIFY=true` (the MCP server has no custom-CA option, only an on/off switch, and this cluster uses a self-signed certificate). It listens on `:8080` (mapped to host `18080`), exposing `/mcp` (Streamable HTTP, no `initialize` call required first) and `/ping` (health check).

No `ES_API_KEY` or username/password is configured, so in `http` mode the server has nothing to fall back on: it forwards the request's own `Authorization` header to Elasticsearch, and a client that sends none is rejected by ROR with a 403.

</details>

## Connect your own MCP client

The endpoint is plain Streamable HTTP at `http://localhost:18080/mcp`; any MCP client works, as long as it can set a header. The generic shape is one remote server plus one `Authorization` header:

```json
{
  "url": "http://localhost:18080/mcp",
  "headers": { "Authorization": "Basic YW5hbHlzdDphbmFseXN0" }
}
```

The headers for the two MCP users: `Basic YW5hbHlzdDphbmFseXN0` (`analyst:analyst`) and `Basic aHI6aHI=` (`hr:hr`) — `printf 'analyst:analyst' | base64` if you want to check.

Swap the header for `admin:admin`'s and the same server, with the same tools, returns everything — a different ROR block, not a different endpoint. The example also ships two preconfigured clients; see below.

## Drive it with two agents

The example ships two [opencode](https://opencode.ai) containers - a terminal agent used here purely as an MCP client, so the ACL can be exercised by a real agent loop instead of by `curl`. They are identical except for one line of config, the `Authorization` header they send:

| Container | Sends | Reaches |
|---|---|---|
| `opencode-analyst` | `Basic YW5hbHlzdDphbmFseXN0` (`analyst:analyst`) | `logs-*`, `orders-*` |
| `opencode-hr` | `Basic aHI6aHI=` (`hr:hr`) | `hr-salaries-*`, `orders-*` |

```bash
docker exec -it opencode-analyst opencode     # in one terminal
docker exec -it opencode-hr opencode          # in another
```

### Signing in (bring your own model)

The containers hold no model credentials. Run `/connect` in the TUI and pick **any provider opencode supports** — the credentials land in the shared `opencode-auth` volume, so signing in once covers both agents, and `./run.sh`'s container recreation does not log you out.

| Sign-in style | Works in the container |
|---|---|
| Paste an API key (any provider) | Yes, nothing else needed |
| Browser sign-in that redirects to `localhost:1455` (OpenAI, ...) | Yes — `opencode-analyst` publishes port 1455, so the redirect from your browser reaches the listener inside the container. Sign in from **that** container; the other one picks the credentials up from the shared volume. |
| Device-code flow (GitHub Copilot: open a URL, type a code) | Yes, no ports involved |
| Code-paste flow (Anthropic Claude Pro/Max: open a URL, paste the code back) | Yes — it needs the `opencode-anthropic-auth` plugin, which is baked into the image and declared under `plugin` in the configs |

Only one container can claim host port 1455, which is why the browser flow has a designated container rather than working from either.

### What to ask them

Ask both agents the same three things and compare:

1. *"which indices can you see?"* — `analyst` sees `logs-2026` and `orders-2026`; `hr` sees `hr-salaries-2026` and `orders-2026`.
2. *"summarise orders-2026"* — both succeed. Shared ground.
3. *"read hr-salaries-2026"* — `hr` reads it; `analyst` gets Elasticsearch's own `index_not_found_exception`. ROR rewrites an out-of-scope index name instead of returning a denial, so the agent usually reports the index does not exist rather than "I was blocked". Mirror it with *"read logs-2026"* to see `hr` blocked the same way.

Then open Kibana as `admin:admin` and look at the ROR audit index: every tool call is attributed to `analyst` or `hr`, never to a shared service account.

### Changing what an agent is

Edit the header in `confs/opencode-analyst.json` / `confs/opencode-hr.json` and `docker restart opencode-analyst`. `admin:admin` is `Basic YWRtaW46YWRtaW4=` if you want an agent with no restrictions for contrast. `opencode mcp add` cannot do this from inside the container — it writes to the global config, which is mounted read-only on purpose so the example's configs do not drift.

## Tool compatibility

All 5 tools were exercised against a live `./run.sh mcp-server` cluster as `analyst`, in scope (`logs-2026`) and out of scope (`hr-salaries-2026`):

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
- A configured key is also a *fallback*: any client that reaches the MCP port without an `Authorization` header would silently inherit the server's identity. With no key configured, unauthenticated clients get a 403 instead.
- Passthrough keeps ROR's audit log meaningful — each MCP call is attributed to the real user, not to one shared `mcp` account.

## What to explore

- Ask `opencode-analyst` to read `hr-salaries-2026` and `opencode-hr` to read `logs-2026` — both are refused, each for its own index; check the ROR audit index for the two identities.
- Log into Kibana as `analyst` and again as `hr`: the same ACL that shapes the agents' tool calls shapes Discover's index list. Writes are refused (`ro`), so saving a search fails on purpose.
- Point a third MCP connection at the same endpoint with `admin:admin` and compare what it sees.
- Run an ES|QL query (`esql` tool) against an in-scope and an out-of-scope index and note the different error shape (400 rather than 404).
- Drop the `Authorization` header entirely and watch ROR reject the call with a 403.

## How to run

```bash
./run.sh mcp-server
```
