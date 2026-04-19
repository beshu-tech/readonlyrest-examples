# ReadonlyREST examples

Ready-to-run Docker examples for various ReadonlyREST deployments with Elasticsearch and Kibana.

## Prerequisites

- Docker with `docker compose` plugin
- A ReadonlyREST activation key (only for examples that require a PRO or ENT license — you will be prompted when needed)

> **Windows users:** use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) (recommended) or Git Bash. PowerShell is not supported.

## Quick start

Run any example with a single command (no clone needed):

```bash
curl -sL https://raw.githubusercontent.com/beshu-tech/readonlyrest-examples/master/quickstart.sh | bash
```

Or pass the example name directly:

```bash
curl -sL https://raw.githubusercontent.com/beshu-tech/readonlyrest-examples/master/quickstart.sh | bash -s basic-multitenancy
```

Some examples require a ReadonlyREST PRO or ENT activation key. If needed, you will be prompted to enter it. You can also set it once as an environment variable:

```bash
export ROR_ACTIVATION_KEY="your-key-here"
```

To stop and clean up:

```bash
curl -sL https://raw.githubusercontent.com/beshu-tech/readonlyrest-examples/master/quickstart.sh | bash -s -- --clean
```

### From a local clone

If you already have the repo cloned:

```bash
./run.sh
```

Or with an example name:

```bash
./run.sh basic-multitenancy
```

To stop and clean up:

```bash
./clean.sh
```

## Available examples

| Example | Description |
|---------|-------------|
| [basic-multitenancy](examples/basic-multitenancy) | Multi-tenancy: isolated Kibana spaces and index access per user |
| [kibana-reverse-proxy](examples/kibana-reverse-proxy) | Two Kibana nodes behind an Apache HTTPS reverse proxy with sticky-session load balancing, SSL termination, and a configurable base-path rewriting strategy |
| [fleet](examples/fleet) | Full Elastic Fleet stack: Fleet Server, Elastic Agent with APM, and an instrumented Node.js service, all secured with ReadonlyREST |

## Project structure

```
examples/                  # One directory per example
  basic-multitenancy/
    .env                   # ES/KBN/ReadonlyREST versions and Dockerfile choice (optional)
    confs/                 # elasticsearch.yml, kibana.yml, readonlyrest.yml
    scripts/               # Lifecycle scripts: init.sh (data seeding), post-start.sh (optional)

  kibana-reverse-proxy/
    .env
    confs/                 # elasticsearch.yml, kibana.yml, readonlyrest.yml
    docker-compose.override.yml  # Additional services (reverse proxy)
    images/                # Dockerfiles for example-specific services
    scripts/               # init.sh, post-start.sh

runner/                    # Shared Docker infrastructure (used by all examples)
  run.sh                   # Main entry point
  clean.sh                 # Stop and remove containers
  docker-compose.yml
  templates/
    kbn-instance.yml.tpl   # Compose service template; one copy rendered per KBN_INSTANCES value
  images/                  # Dockerfiles for ES, KBN, and cluster-initializer
  conf/                    # TLS certs and shared config (log4j2, keystores)
  utils/
    setup-compose-files.sh      # Assembles the final list of -f flags passed to docker compose
    generate-kbn-instances.sh   # Renders kbn-instance.yml.tpl for each Kibana instance
    ...                         # Version collection, license detection, etc.
```

## How it works

`run.sh <example>` validates the example directory, copies its `.env` (if present) into the environment, detects the ReadonlyREST license edition, and launches the cluster via `docker compose`. Config files from the example's `confs/` directory are volume-mounted into the containers at runtime. The example's `README.md` title and first paragraph are printed at startup to identify what is being run.

If no `.env` is provided, the script falls back to interactive prompts to collect ES/KBN version info.

### Multiple Kibana instances

Setting `KBN_INSTANCES=N` in an example's `.env` spins up N Kibana nodes. The runner renders `runner/templates/kbn-instance.yml.tpl` once per instance, assigning each a unique service name (`kbn-ror`, `kbn-ror-2`, …) and host port (`15601`, `15602`, …). The generated Compose fragment is merged into the final `docker compose` invocation automatically — no manual edits to any Compose file are needed.

### Dynamic kibana.yml settings

If an example provides `scripts/kibana-conf-extra-settings.sh`, the runner appends its stdout to `confs/kibana.yml` before mounting the file into the container. Use this to inject settings that depend on runtime environment variables (e.g. `server.rewriteBasePath`) without duplicating the base config.

## Creating a new example

1. Create a directory under `examples/` (e.g. `examples/my-example`)
2. Add the required config files:
   - `confs/elasticsearch.yml`
   - `confs/readonlyrest.yml`
   - `confs/kibana.yml`
3. Add a `README.md` with a title (`# My Example`) and a short description paragraph — these are printed at startup
4. Optionally add a `.env` to pin ES/KBN/ReadonlyREST versions (see `examples/basic/.env` for the format)
   - Set `KBN_INSTANCES=N` to start N Kibana nodes instead of one
5. Optionally add `scripts/init.sh` to seed data after the cluster starts (it can `source /usr/local/lib/ror-utils.sh` for helper functions like `createIndex`, `putDocument`, etc.)
6. Optionally add `scripts/post-start.sh` to print custom access instructions or run post-startup steps; if absent, the default Kibana URL is printed
7. Optionally add `scripts/kibana-conf-extra-settings.sh` to emit extra `kibana.yml` lines at runtime (its stdout is appended to `confs/kibana.yml` before the container starts)
8. Optionally add `docker-compose.override.yml` to define extra services (e.g. a reverse proxy); it is automatically picked up and merged with the base compose file
9. Run it: `./run.sh my-example`
