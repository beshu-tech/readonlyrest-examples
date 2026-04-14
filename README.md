# readonlyrest-examples
Ready-to-run Docker examples for various ReadonlyREST deployments with Elasticsearch and Kibana.

## Prerequisites

- Docker with `docker compose` plugin
- `ROR_ACTIVATION_KEY` environment variable set with a valid ReadonlyREST activation key

## Quick start

```bash
export ROR_ACTIVATION_KEY="your-key-here"
./run.sh basic
```

To stop and clean up:

```bash
./clean.sh
```

## Available examples

| Example | Description |
|---------|-------------|
| [basic](examples/basic) | Multi-tenancy: isolated Kibana spaces and index access per user |

## Project structure

```
examples/                  # One directory per example
  basic/
    .env                   # ES/KBN/ROR versions and Dockerfile choice (optional)
    confs/                 # elasticsearch.yml, kibana.yml, readonlyrest.yml
    init/                  # Init scripts run after the cluster starts
    README.md

runner/                    # Shared Docker infrastructure (used by all examples)
  run.sh                   # Main entry point (also at repo root)
  clean.sh                 # Stop and remove containers (also at repo root)
  docker-compose.yml
  images/                  # Dockerfiles for ES, KBN, and cluster-initializer
  conf/                    # TLS certs and shared config (log4j2, keystores)
  utils/                   # Helper scripts (version collection, license detection)
```

## How it works

`run.sh <example>` validates the example directory, copies its `.env` (if present) into the environment, detects the ROR license edition, and launches the cluster via `docker compose`. Config files from the example's `confs/` directory are volume-mounted into the containers at runtime. The example's `README.md` title and first paragraph are printed at startup to identify what is being run.

If no `.env` is provided, the script falls back to interactive prompts to collect ES/KBN version info.

## Creating a new example

1. Create a directory under `examples/` (e.g. `examples/my-example`)
2. Add the required config files:
   - `confs/elasticsearch.yml`
   - `confs/readonlyrest.yml`
   - `confs/kibana.yml`
3. Add a `README.md` with a title (`# My Example`) and a short description paragraph — these are printed at startup
4. Optionally add a `.env` to pin ES/KBN/ROR versions (see `examples/basic/.env` for the format)
5. Optionally add `init/init.sh` to seed data after the cluster starts (it can `source /usr/local/lib/ror-utils.sh` for helper functions like `createIndex`, `putDocument`, etc.)
6. Run it: `./run.sh my-example`
