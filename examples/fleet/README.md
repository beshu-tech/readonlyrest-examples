# Fleet with ReadonlyREST

Elastic Fleet managed observability stack secured with ReadonlyREST.

Runs a full Elastic stack — Elasticsearch and Kibana with ReadonlyREST, a Fleet Server, an Elastic Agent collecting metrics and APM traces, a small Node.js service instrumented with the APM client, and a traffic simulator that generates continuous load.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Docker network (ror-network)                           │
│                                                         │
│  es-ror ──────────────────────────── kbn-ror            │
│     │                                   │               │
│     │         fleet-server ─────────────┘               │
│     │              │                                    │
│     │         fleet-initializer (one-shot)              │
│     │                                                   │
│     └──────── apm-agent (APM server on :8200)           │
│                    │                                    │
│               demo-app (Node.js + APM client)           │
│                    │                                    │
│               traffic-simulator (curl loop)             │
└─────────────────────────────────────────────────────────┘
```

## Exposed ports

| Service       | Host port | Description              |
|---------------|-----------|--------------------------|
| Kibana        | 15601     | ReadonlyREST Kibana UI   |
| Fleet Server  | 8220      | Fleet enrollment endpoint|
| Agent (APM)   | 8201      | APM server               |
| demo-app      | 3001      | Instrumented Node.js app |

## Users

| Username | Password | Groups                                  |
|----------|----------|-----------------------------------------|
| admin    | admin    | Administrators + End Users + Business Users |
| user1    | test     | End Users + Business Users              |
| user2    | test     | End Users only                          |

## What to explore

- **Fleet** → open Kibana as `admin` and navigate to Management → Fleet to see the enrolled agent and its policy
- **APM** → navigate to Observability → APM to see traces from `demo-app`
- **Metrics** → navigate to Observability → Metrics to see system metrics from `apm-agent`
- **Multi-tenancy** → log in as `user1` or `user2` to see isolated Kibana spaces with restricted index access

## How to run

```bash
export ROR_ACTIVATION_KEY="your-key-here"
./run.sh fleet
```
