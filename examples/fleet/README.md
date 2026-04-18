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

| Username | Password |
|----------|----------|
| admin    | admin    |

## How it works

<details>
<summary>Step 1 — Elasticsearch starts with ReadonlyREST</summary>

Elasticsearch starts with `xpack.security` TLS enabled (required for Fleet transport encryption) and the ReadonlyREST plugin loaded. ReadonlyREST takes over all authentication and authorization. The `readonlyrest.yml` defines four ACL rules:

- **KIBANA** — allows Kibana's internal user (`kibana:kibana`) full access so Kibana can read/write its own saved objects and system indices.
- **Fleet server** — allows the Fleet Server's service token to read and write `.fleet-*` indices (agents, policies, enrollment keys, etc.).
- **Agents** — allows enrolled Elastic Agents (identified by their Fleet-issued API keys) to write telemetry data into `metrics-*`, `traces-*`, and `logs-*`.
- **Forbid access to service accounts and API keys** — blocks Fleet from creating native Elasticsearch service accounts or API keys via the xpack security API. This is the key rule that makes Fleet work with ROR: Fleet falls back to its own token-based enrollment mechanism instead of relying on the native security layer.
- **Admins** — grants the `admin:admin` user full Kibana admin access.

</details>

<details>
<summary>Step 2 — Kibana starts with ReadonlyREST Kibana plugin</summary>

Kibana connects to Elasticsearch using the `kibana:kibana` credentials defined in `kibana.yml`. On startup Kibana pre-installs the `fleet_server` and `system` integration packages and creates a **Fleet Server Policy** (`fleet-server-policy`) via `xpack.fleet.agentPolicies`. This policy is used exclusively by the Fleet Server container in the next step.

</details>

<details>
<summary>Step 3 — Fleet Server enrolls itself</summary>

Once both Elasticsearch and Kibana are healthy, the `fleet-server` container (running `elastic-agent`) starts. It uses `KIBANA_FLEET_SETUP=1` to let Fleet Server bootstrap Fleet in Kibana on first run. It authenticates to both Kibana and Elasticsearch with `kibana:kibana`, connects to Kibana at `https://kbn-ror:5601`, and registers itself as a Fleet Server on port 8220 with TLS.

</details>

<details>
<summary>Step 4 — Fleet Initializer configures agent policies (one-shot)</summary>

After the Fleet Server is healthy, the `fleet-initializer` container runs once and exits. It calls the Kibana Fleet API to:

1. Create an **Agent Policy** (`elastic-policy`) — the policy that regular (non-server) agents will enroll into.
2. Add a **System integration** to the policy — instructs enrolled agents to collect system metrics (CPU, memory, disk, network).
3. Add an **APM integration** to the policy — instructs one of the enrolled agents to run an APM Server on `0.0.0.0:8200` with TLS, reachable inside the network as `https://apm-agent:8200`.
4. Register/update the **Fleet Server Host** URL (`https://fleet-server:8220`) so agents know where to enroll.
5. Update the **default Fleet output** to point at `https://es-ror:9200` with the shared CA certificate, so agents ship data directly to Elasticsearch.

</details>

<details>
<summary>Step 5 — APM Agent enrolls and starts the APM Server</summary>

The `apm-agent` container runs after the initializer completes. Its entrypoint first fetches the enrollment token for `elastic-policy` from the Kibana Fleet API, then starts `elastic-agent` with that token. Fleet delivers the policy to the agent, which spins up:
- The **APM Server** integration (listening on `:8200` with TLS)
- The **system metrics** integration (sending host metrics to Elasticsearch)

</details>

<details>
<summary>Step 6 — Demo App sends traces</summary>

The `demo-app` is a small Node.js / Express application instrumented with the Elastic APM Node.js agent. It connects to the APM Server at `https://apm-agent:8200` and reports every request as a trace. It exposes two endpoints:
- `GET /` — responds after a simulated 1-second delay; creates a custom APM transaction.
- `GET /error` — captures and reports an APM error, returns HTTP 500.

</details>

<details>
<summary>Step 7 — Traffic Simulator generates load</summary>

The `traffic-simulator` container runs a continuous `curl` loop (every 5 seconds) against `demo-app`. Roughly 10% of requests target `/error` and the rest target `/`, producing a steady stream of APM traces and occasional errors visible in Kibana.

</details>

## What to explore

- **Fleet** → open Kibana as `admin` and navigate to Management → Fleet to see the enrolled agent and its policy
- **APM** → navigate to Observability → APM to see traces from `demo-app`
- **Metrics** → navigate to Observability → Metrics to see system metrics from `apm-agent`

## How to run

```bash
./run.sh fleet
```
