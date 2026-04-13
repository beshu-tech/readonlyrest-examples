# Kibana Reverse Proxy Example

Demonstrates running two Kibana nodes behind an Apache HTTPS reverse proxy with sticky-session load balancing, SSL termination at the proxy layer, and a configurable base-path rewriting strategy.

Multi-tenancy is configured the same way as in the `basic` example: different users get isolated Kibana spaces with different index access and app visibility.

## Architecture

```
                    HTTPS :8443
Browser ──────────────────────────► Apache reverse proxy
                                         │
                            /ror-demo    │  sticky-session load balancer
                                         │  (ROUTEID cookie, byrequests)
                            ┌────────────┴────────────┐
                            ▼                         ▼
               kbn-ror  (HTTPS :5601)     kbn-ror-2  (HTTPS :5601)
               exposed: :15601            exposed: :15602
                            │                         │
                            └────────────┬────────────┘
                                         ▼
                          Elasticsearch + ROR  (HTTPS :9200)
```

Key characteristics:
- **SSL termination** at the proxy; Kibana nodes also use HTTPS internally (proxy-to-backend traffic is encrypted)
- **Sticky sessions** via the `ROUTEID` cookie — a client stays pinned to the same Kibana node across requests
- **Base path** `/ror-demo` — Kibana is served at a sub-path, not at the root
- **Configurable path rewriting** — either Kibana or Apache can own the `/ror-demo` prefix stripping (see [Path rewriting mode](#path-rewriting-mode))

## Users

| Username | Password | Role                     | Kibana access | Visible indices                                   |
|----------|----------|--------------------------|---------------|---------------------------------------------------|
| `admin`  | `admin`  | Administrator            | Full admin    | All                                               |
| `user1`  | `test`   | End User + Business User | Read/Write    | `*-frontend-*`, `*-business-*`, `kibana_sample_data_*` |
| `user2`  | `test`   | End User                 | Read/Write    | `*-frontend-*`, `kibana_sample_data_*`            |

## How to run

```bash
./run.sh kibana-reverse-proxy
```

`ROR_ACTIVATION_KEY` must be set in your shell environment before running.

Access points after startup:

| Entry point | URL |
|-------------|-----|
| Via reverse proxy (main) | https://localhost:8443/ror-demo |
| Direct kbn-ror | https://localhost:15601/ror-demo |
| Direct kbn-ror-2 | https://localhost:15602/ror-demo |

## Path rewriting mode

The `.env` file contains a `REWRITE_BASE_PATH_BY_KIBANA` flag that controls which component is responsible for stripping the `/ror-demo` base path prefix before processing requests:

| Value | Who strips `/ror-demo` | Kibana `server.rewriteBasePath` | Apache behaviour |
|-------|------------------------|----------------------------------|-----------------|
| `true` (default) | Kibana | `true` | `ProxyPass /ror-demo → kbn:5601/ror-demo` (prefix preserved) |
| `false` | Apache | `false` | `RewriteRule` strips prefix before forwarding to Kibana |

Change the value in `.env` before starting the stack to switch modes. Both modes produce the same end-user experience; the difference is which layer owns the path translation.

The `server.rewriteBasePath` setting is injected dynamically at container start via `scripts/kibana-conf-extra-settings.sh` — no manual edits to `confs/kibana.yml` are needed.

## What to explore

- Log in as `admin` to see all indices and full Kibana admin access.
- Log in as `user1` or `user2` to see tenant-isolated spaces with restricted index access and hidden Security/Observability apps.
- Refresh the page repeatedly while logged in — the `ROUTEID` cookie pins you to one Kibana instance (sticky sessions), but you can clear it to observe the load balancer routing to the other node.
- Bypass the proxy and hit `kbn-ror` or `kbn-ror-2` directly on ports `:15601` / `:15602` to verify each node works independently.
- Set `REWRITE_BASE_PATH_BY_KIBANA=false` in `.env`, rebuild, and verify that proxy-side rewriting produces the same result from the browser's perspective.
