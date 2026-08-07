# PKI Auth Example

Demonstrates authenticating services by their TLS client certificate: ReadonlyREST derives the username and groups from the certificate, while password-based users share the same port.

## Users

| Identity        | Credential                                       | Group    | Kibana access | Access to `logs-*` |
|-----------------|--------------------------------------------------|----------|---------------|--------------------|
| `svc-logstash`  | Certificate `CN=svc-logstash,OU=ingest,OU=Services` | `ingest` | None          | Write              |
| `svc-dashboard` | Certificate `CN=svc-dashboard,OU=query,OU=Services` | `query`  | None          | Read               |
| `jsmith`        | Certificate `CN=jsmith,OU=ingest,OU=People`      | —        | None          | Refused            |
| `analyst`       | Password `analyst`                               | —        | Read-only     | Read               |

The three certificates come from the same CA. None of the services holds a password.

`jsmith` is refused even though the node trusts that certificate and it carries the same `ingest` role, because the certificate is issued into the People branch and the PKI provider declares `subject_dn_base: "OU=Services,DC=corp,DC=example,DC=com"`. One corporate CA usually issues to more than one population, and without that constraint a `CN` extractor would authenticate humans as services.

## How to run

```bash
curl -sL https://raw.githubusercontent.com/beshu-tech/readonlyrest-examples/master/quickstart.sh | bash -s pki-auth
```

From a local clone it is just `./run.sh pki-auth`.

Access points after startup:

| Entry point   | URL                      |
|---------------|--------------------------|
| Elasticsearch | https://localhost:19200  |
| Kibana        | https://localhost:15601  |

## What to explore

Run these from the example directory. No credential is passed other than the certificate.

- Write as `svc-logstash`, authenticated by certificate alone:

  ```bash
  curl -sk --cert certs/svc-logstash.crt --key certs/svc-logstash.key \
       -XPOST https://localhost:19200/logs-2026/_doc \
       -H 'Content-Type: application/json' -d '{"msg":"hello"}'
  ```

- Read with the same certificate — forbidden, because the `ingest` group only grants writes:

  ```bash
  curl -sk --cert certs/svc-logstash.crt --key certs/svc-logstash.key https://localhost:19200/logs-2026/_search
  ```

- Read as `svc-dashboard` — a different certificate, a different group, reads allowed:

  ```bash
  curl -sk --cert certs/svc-dashboard.crt --key certs/svc-dashboard.key https://localhost:19200/logs-2026/_search
  ```

- Try `jsmith` — trusted by the same CA, but refused for being outside `subject_dn_base`:

  ```bash
  curl -sk --cert certs/jsmith.crt --key certs/jsmith.key https://localhost:19200/logs-2026/_search
  ```

- Send no certificate at all — the request falls through to the password block on the very same port:

  ```bash
  curl -sk -u analyst:analyst https://localhost:19200/logs-2026/_search
  ```

- Watch a real client do the same thing. A Logstash container ships to `logs-2026` using the `svc-logstash` certificate and no password at all — its config holds no credential other than the certificate ([`confs/logstash.conf`](confs/logstash.conf)). It reports every event it sends:

  ```bash
  docker logs -f $(docker ps -qf name=logstash)
  ```

- Watch the data arrive, reading with a *different* certificate. Run this twice a few seconds apart — the count goes up:

  ```bash
  curl -sk --cert certs/svc-dashboard.crt --key certs/svc-dashboard.key \
       'https://localhost:19200/logs-2026/_count'
  ```

  That is the whole point in one line: `svc-logstash` wrote it and cannot read it back, `svc-dashboard` reads it and cannot write, and neither of them holds a password.

- Log in to Kibana as `analyst:analyst`. A browser never presents a client certificate, so Kibana authenticates with a password on the same port the services use certificates on.

## How it is configured

The node asks for a certificate and verifies it ([`confs/elasticsearch.yml`](confs/elasticsearch.yml)):

```yaml
xpack.security.http.ssl.client_authentication: optional
xpack.security.http.ssl.verification_mode: certificate
xpack.security.http.ssl.certificate_authorities: [ "ca.crt", "pki-ca.crt" ]
```

`optional` rather than `required`, so a caller without a certificate still reaches the ACL and can fall through to the password block. `required` would reject it during the handshake instead, and `analyst` would never get in.

ReadonlyREST turns the certificate into a user ([`confs/readonlyrest.yml`](confs/readonlyrest.yml)):

```yaml
pkis:
  - name: corporate_pki
    subject_dn_base: "OU=Services,DC=corp,DC=example,DC=com"
    issuer_dn: "CN=Corp Issuing CA,DC=corp,DC=example,DC=com"
    users:
      user_id_attribute: "CN"
    groups:
      group_id_attribute: "OU"
```

The groups it reads are *external* groups, mapped to local ones in the `users` section. Every certificate here carries two OUs — `OU=ingest` names a role, `OU=Services` merely places it in the corporate tree — and only the role is mapped. The other is discarded.

The certificates are generated by [`certs/generate.sh`](certs/generate.sh), which you can rerun. The distinguished names are part of the configuration: change them and `confs/readonlyrest.yml` has to change with them.

## Things to check in your own cluster

- **TLS must terminate at Elasticsearch.** If a load balancer, ingress or service mesh terminates it upstream, no certificate ever reaches the node and PKI rules never match. This is the most common reason PKI appears not to work.
- **Kibana cannot use PKI.** A browser presents no client certificate, so anything reaching Elasticsearch through Kibana authenticates as Kibana's own service account. Keep a password or SSO path for people.
- **Never set `verification_mode: none`.** The node would still ask for a certificate and then validate nothing, so anyone able to run a CA could issue one saying `CN=svc-logstash` and be authenticated as that service. ReadonlyREST cannot detect this. `issuer_dn` is the one constraint a forged subject still cannot satisfy.
- **Order your blocks.** If a request carries both a certificate and an `Authorization` header, the first matching block decides the identity. Put password blocks for known service accounts above the PKI blocks.
