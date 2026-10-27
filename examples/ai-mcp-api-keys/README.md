# AI/MCP API Keys

This example demonstrates how ReadonlyREST enables AI/MCP-style access to Elasticsearch using Elasticsearch-native API keys. It shows how to issue per-user, read-only, index-restricted, expirable, and revocable API keys for use by AI assistants or MCP (Model Context Protocol) clients, and how those keys are audited through ROR's audit log.

## What this example demonstrates

- Issuing Elasticsearch-native API keys for AI/MCP tool access
- Read-only action enforcement via ROR ACL (`indices:data/read/*`)
- Index scope restriction via ROR ACL (AI/MCP tokens can only reach `*-reports`, not `*-logs`)
- API key expiration (configured at creation time)
- API key revocation and verification that revoked keys are rejected
- Audit logging for API-key-authenticated requests via the `readonlyrest_audit-*` index

## User simulation

Alice and Bob are simulated using ReadonlyREST local users with `auth_key` credentials defined in the `users` section of `readonlyrest.yml`. LDAP is intentionally not used in this PoC. In a production deployment, Alice and Bob would correspond to real users from an identity provider (LDAP, SAML, OIDC). The local users stand in for per-user access rules that would be defined in the production ACL.

## Fake AI/MCP service

`fake-ai-mcp-query.sh` is not a real MCP server or AI assistant. It is a minimal shell script that simulates an AI/MCP client querying Elasticsearch using a user-specific API key via `Authorization: ApiKey <encoded-key>`. In a real deployment, the MCP server or AI assistant would obtain and store the API key and make equivalent Elasticsearch requests. The important aspects of this PoC are authentication, authorization, revocation, expiration, and audit behaviour — not AI logic.

## Architecture

```
simulated alice / bob
       |
       | each user creates their own API key (alice:alice / bob:bob)
       v
 fake-ai-mcp-query.sh
       |
       | Authorization: ApiKey <user-api-key>
       v
 ReadonlyREST
       |
       | 1. validates Elasticsearch-native API key
       | 2. applies read-only action ACL (indices:data/read/*)
       | 3. applies AI/MCP index scope (alice-reports, bob-reports)
       | 4. writes audit event to readonlyrest_audit-*
       v
 Elasticsearch
       ├── alice-logs    (local user access only — outside AI/MCP scope)
       ├── bob-logs      (local user access only — outside AI/MCP scope)
       ├── alice-reports (AI/MCP API key access)
       └── bob-reports   (AI/MCP API key access)
```

ROR enforces the read-only constraint and the AI/MCP index scope (`alice-reports`, `bob-reports`). AI/MCP tokens cannot reach the operational log indices (`alice-logs`, `bob-logs`) regardless of which user's key is used.

## How to run

### Start

From the repository root:

```bash
./run.sh ai-mcp-api-keys
```

### Run the demo

```bash
cd examples/ai-mcp-api-keys
bash scripts/demo.sh
```

`demo.sh` performs the full lifecycle:

1. Creates Alice's API key (expires in 1 day)
2. Creates Bob's API key (expires in 1 day)
3. Runs all query and write scenarios through `fake-ai-mcp-query.sh`
4. Revokes Alice's API key and verifies the revoked key is rejected

### Manual fake AI/MCP queries

After `demo.sh` has run once (to create API keys in `.runtime-keys/`):

```bash
cd examples/ai-mcp-api-keys

bash scripts/fake-ai-mcp-query.sh alice alice-reports   # allowed
bash scripts/fake-ai-mcp-query.sh alice alice-logs      # denied — logs outside AI/MCP scope
bash scripts/fake-ai-mcp-query.sh bob   bob-reports     # allowed
bash scripts/fake-ai-mcp-query.sh bob   alice-logs      # denied — logs outside AI/MCP scope
```

The `ES` environment variable can be set to override the default Elasticsearch address:

```bash
ES=https://localhost:19200 bash scripts/fake-ai-mcp-query.sh alice alice-reports
```

### Stop and clean up

From the repository root:

```bash
./clean.sh
```

Generated API key files are stored in `examples/ai-mcp-api-keys/.runtime-keys/` and are excluded from version control via `.gitignore`.

## Expected results

| Scenario | Expected | Enforced by |
|---|---|---|
| Alice API key queries `alice-reports` | Allowed (HTTP 200) | ROR ACL |
| Alice API key queries `alice-logs` | Denied (HTTP 403) | ROR ACL — logs outside AI/MCP index scope |
| Bob API key queries `bob-reports` | Allowed (HTTP 200) | ROR ACL |
| Bob API key queries `alice-logs` | Denied (HTTP 403) | ROR ACL — logs outside AI/MCP index scope |
| Alice API key writes to `alice-reports` | Denied (HTTP 403) | ROR ACL — read-only action enforcement |
| Bob API key writes to `bob-reports` | Denied (HTTP 403) | ROR ACL — read-only action enforcement |
| Alice revoked API key queries `alice-reports` | Rejected (HTTP 403) | ROR — key no longer valid |

## Auditability

ROR writes an audit event for every request to the `readonlyrest_audit-*` index. The index pattern is created automatically by the init script. To inspect events:

1. Open [https://localhost:15601/s/default/app/discover](https://localhost:15601/s/default/app/discover) and log in as `admin:admin`
2. Select the `readonlyrest_audit-*` index pattern

Audit fields visible in this example:

| Field | Value |
|---|---|
| `user` | `ai-mcp` (the username assigned to the ROR ACL block for all API key requests) |
| `acl_block` | `AI/MCP API key access` (allowed) or `FORBIDDEN` (denied) |
| `action` | e.g. `indices:data/read/search` |
| `indices` | target index |
| `type` | `ALLOWED` or `FORBIDDEN` |

Note: the audit log records the logical username configured in the `token_authentication` block (`ai-mcp`), not the identity of the API key creator. The API key name and id are not directly available in ROR audit fields in this configuration. Use Elasticsearch's own `GET /_security/api_key` endpoint (with admin credentials) to correlate key ids with named keys.

## Security notes

- This is a local PoC. Credentials and generated API keys are for demonstration purposes only.
- API key files are stored in `.runtime-keys/` and are excluded from version control.
- In production, API key issuance should be gated by your identity management system and automated through a controlled service, not run manually.
- Rate limiting and query throttling are not implemented in this PoC. These belong at the API gateway, proxy, MCP layer, or load balancer layer — not within ROR or Elasticsearch.
- This is not a production-ready MCP server implementation.
