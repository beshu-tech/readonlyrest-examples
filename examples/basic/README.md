# Basic Example

Demonstrates ReadonlyREST's core multi-tenancy feature: different users get isolated Kibana spaces with different index access and app visibility, all driven by a single `readonlyrest.yml`.

## Users

| Username | Password | Role            | Kibana access | Visible indices                          |
|----------|----------|-----------------|---------------|------------------------------------------|
| `admin`  | `admin`  | Administrator   | Full admin    | All                                      |
| `user1`  | `test`   | End User + Business User | Read/Write | `*-frontend-*`, `kibana_sample_data_*` |
| `user2`  | `test`   | End User        | Read/Write    | `*-frontend-*`, `kibana_sample_data_*`  |

## How to run

```bash
./enviroment/run.sh basic
```

`ROR_ACTIVATION_KEY` must be set in your shell environment before running.

## What to explore

- Log in as `admin` to see all indices and full Kibana admin access.
- Log in as `user1` to see only `frontend-logs` and `business-reports` indices, with Security and Observability apps hidden.
- Log in as `user2` to see only `frontend-logs`, with Security and Observability apps hidden.
- Each user gets an isolated Kibana saved-objects space (`.kibana_end_<user>` / `.kibana_business_<user>`).
