# Kibana Reverse Proxy Example

Demonstrates running Kibana behind an Apache HTTPS reverse proxy with load balancing across two Kibana instances. Multi-tenancy is configured the same way as in the `basic` example: different users get isolated Kibana spaces with different index access and app visibility.

## Architecture

```
Browser → Apache reverse proxy (https://localhost:8443/ror-demo)
               ↓ sticky-session load balancing
    ┌──────────────────────────┐
    │  kbn-ror   (:15601)      │
    │  kbn-ror-2 (:15602)      │
    └──────────────────────────┘
               ↓
    Elasticsearch with ROR (:9200)
```

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
- Via reverse proxy: https://localhost:8443/ror-demo
- Direct kbn-ror: https://localhost:15601/ror-demo
- Direct kbn-ror-2: https://localhost:15602/ror-demo

## Path rewriting mode

The `.env` file contains a `REWRITE_BASE_PATH_BY_KIBANA` flag that controls which component is responsible for stripping the `/ror-demo` base path prefix:

| Value | Who strips `/ror-demo` | Kibana `server.rewriteBasePath` | Apache behaviour |
|-------|------------------------|----------------------------------|-----------------|
| `true` (default) | Kibana | `true` | `ProxyPass /ror-demo → kbn:5601/ror-demo` |
| `false` | Apache | `false` | `RewriteRule` strips prefix before forwarding |

Change the value in `.env` before starting the stack to switch modes. Both modes produce the same end-user experience; the difference is which layer owns the path translation.

## What to explore

- Log in as `admin` to see all indices and full Kibana admin access.
- Log in as `user1` or `user2` to see tenant-isolated spaces with restricted index access and hidden Security/Observability apps.
- Each user gets an isolated Kibana saved-objects space (`.kibana_end_<user>` / `.kibana_business_<user>`).
- Refresh the page repeatedly while logged in — the `ROUTEID` cookie pins you to one Kibana instance (sticky sessions), but you can clear it to observe the load balancer routing to the other node.
- Set `REWRITE_BASE_PATH_BY_KIBANA=false` in `.env`, rebuild, and verify the proxy-side rewriting works identically from the browser's perspective.
