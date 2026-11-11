# Personal API keys with ReadonlyREST

A user creates an Elasticsearch API key, and each request with the key runs as that user. ROR reads the current LDAP groups of the user on each request. When the groups change, the access of the key changes too. Each user manages only own keys. The users in `api_key_admins` manage all keys.

Users manage their keys with the Elasticsearch API or on the Kibana page **Stack Management → Security → API keys**.

> Both ROR plugins in this example are pre-release builds: Elasticsearch `1.74.0-pre2` and Kibana `1.74.0-pre1`. Build them before you run the example (see [Build the ROR plugins](#build-the-ror-plugins)).

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Docker network (ror-network)                                │
│                                                              │
│  ldap (OpenLDAP) ◄── groups ── es-ror ─────────── kbn-ror    │
│                                   │                          │
│                                   └── initializer (one-shot: │
│                                       logstash-banana-2026,  │
│                                       logstash-apple-2026)   │
└──────────────────────────────────────────────────────────────┘
          ▲
          │ curl -u alice:alice  /  Authorization: ApiKey ...
        host (demo.sh)
```

## Exposed ports

| Service       | Host port | Description            |
|---------------|-----------|------------------------|
| Elasticsearch | 19200     | ROR-secured ES (HTTPS) |
| Kibana        | 15601     | ReadonlyREST Kibana UI |

## Users

| Username | Password | Source | Groups                             | Can do                                       |
|----------|----------|--------|------------------------------------|----------------------------------------------|
| admin    | admin    | local  | -                                  | Kibana admin. Manages all API keys.          |
| alice    | alice    | LDAP   | ai-users, readAccessToIndex-banana | Kibana user. Manages own keys. Her keys read `logstash-banana-*`. |
| bob      | bob      | LDAP   | ai-users, readAccessToIndex-apple  | Kibana user. Manages own keys. His keys read `logstash-apple-*`.  |
| carol    | carol    | LDAP   | readAccessToIndex-banana           | Cannot create API keys and cannot log in to Kibana (not in `ai-users`). |

The Kibana tech user `kibana` is also in `api_key_admins`. Kibana can invalidate the keys of other users, for example when you unenroll a Fleet agent.

## ReadonlyREST settings

See [`confs/readonlyrest.yml`](confs/readonlyrest.yml). The important parts:

```yaml
readonlyrest:
  global_settings:
    api_key_admins: ["kibana", "admin"]

  access_control_rules:
    - name: "Manage own API keys"
      type: allow
      ldap_authentication: "ldap1"
      ldap_authorization: { name: "ldap1", groups_any_of: ["ai-users"] }
      actions: ["cluster:admin/xpack/security/api_key/create",
                "cluster:admin/xpack/security/api_key/invalidate",
                "cluster:admin/xpack/security/api_key/get",
                "cluster:admin/xpack/security/api_key/update"]

    - name: "banana - API key"
      type: allow
      token_authentication:
        type: "api-key"            # no username: the request runs as the owner of the key
      ldap_authorization: { name: "ldap1", groups_any_of: ["readAccessToIndex-banana"] }
      indices: ["logstash-banana-*"]
      actions: ["indices:data/read/*", "indices:admin/shards/search_shards"]

    - name: "Kibana - ai-users"
      type: allow
      ldap_auth: { name: "ldap1", groups_any_of: ["ai-users"] }
      kibana:
        access: rw
```

The `kibana` rule allows the API key actions. Thus a block that forbids API key management must come before the Kibana block of the user.

In a production setup, users usually log in to Kibana with SSO and create keys there. Replace `ldap_authentication` with `ror_kbn_auth` for that (it needs a ROR Enterprise license).

## How it works

1. alice creates a key with `POST /_security/api_key`. ROR adds `"_ror": {"owner": "alice"}` to the key metadata and keeps her own metadata fields.
2. A request with the key matches `token_authentication` with `type: api-key` and no `username`. ROR logs in the owner of the key: alice.
3. `ldap_authorization` reads the groups of alice from LDAP. The block allows the request only if she is in `readAccessToIndex-banana` now.

Elasticsearch rejects client metadata keys that start with `_`. Thus a client cannot set the owner of a new key.

The get and query APIs show the `_ror` object with the other metadata. A client can send this metadata back in an update, for example from the Kibana edit form. ROR replaces the `_ror` object of the update request with the stored one. Thus an update cannot change the owner.

ROR does not let a request with an API key create a new key. A key cannot make a key that stays valid after you revoke the first key.

A user who is not an API key admin can revoke keys only by their IDs, and only own keys. The `owner` flag can come with the IDs. An ID that does not exist selects no key, so ROR allows it.

## The Kibana API keys page

ROR Kibana shows the API keys page on Kibana 7.14.0 and newer. From this version, ROR Elasticsearch checks the owner of each API key.

On the page:

- alice and bob see only their own keys. admin sees the keys of all users.
- The owner column shows the ROR user who created the key. The page has no owner filter.
- A user can edit only own keys. admin can revoke the keys of other users, but cannot edit them.
- The create and edit forms do not show the security privileges section. ROR does not use role descriptors: the ROR ACL decides what a key can do.
- Only admin can create cross-cluster API keys. The page shows this option to alice and bob too, but ROR rejects their request. Cross-cluster API keys also need an Enterprise or trial license of Elasticsearch.

Try it:

1. Log in to https://localhost:15601 as `alice:alice`.
2. Open **Stack Management → Security → API keys** and create a key. The owner column shows `alice`.
3. Log in as `bob:bob`. bob does not see the key of alice.
4. Log in as `alice:alice` again and edit her key. The metadata field shows the `_ror` object. Add a field and save. The owner stays `alice`.
5. Log in as `admin:admin`. admin sees the keys of alice and bob with their owners.

## Run the example

### Build the ROR plugins

In the `elasticsearch-readonlyrest-plugin` repository, on the branch with personal API keys:

```bash
./gradlew clean buildRorPlugin -PesVersion=9.5.6
mkdir -p <readonlyrest-examples>/runner/ror-builds
cp es94x/build/distributions/readonlyrest-1.74.0-pre2_es9.5.6.zip <readonlyrest-examples>/runner/ror-builds/
```

In the `readonlyrest_kbn` repository, on the branch with the API keys page:

```bash
yarn gulp --es_version=9.5.6
cp build/readonlyrest_kbn_universal-1.74.0-pre1_es9.5.6.zip <readonlyrest-examples>/runner/ror-builds/
```

The `runner/` directory is the Docker build context. Thus the zips must be in `runner/ror-builds/` (Git ignores this directory). If the version of a build is different, change `ROR_ES_FILE` or `ROR_KBN_FILE` in [`.env`](.env).

### Start the stack

```bash
./run.sh personal-api-keys
```

### Walk through the features

```bash
./examples/personal-api-keys/demo.sh
```

The script needs `curl` and `docker` on the host. It checks each step and ends with `All steps passed.`:

| Step | What happens | Expected |
|------|--------------|----------|
| 1  | alice creates a key. `GET /_security/api_key` shows `metadata._ror.owner: alice`. | 200 |
| 2  | bob creates a key. | 200 |
| 3  | carol creates a key. She is not in `ai-users`. | 403 |
| 4  | alice creates a key with `"_ror": {"owner": "bob"}` in the metadata. | 400 |
| 5  | alice updates her key and sends back the metadata with `"_ror": {"owner": "alice"}`, as Kibana does. The owner stays `alice`. | 200 |
| 6  | alice updates her key with `"_ror": {"owner": "bob"}` in the metadata. ROR ignores it, and the owner stays `alice`. | 200 |
| 7  | alice's key reads `logstash-banana-2026`, bob's key reads `logstash-apple-2026`. Each key gets 404 for the other index, because ROR hides an index that the user cannot read. | 200 / 404 |
| 8  | alice's key tries to create a key. | 403 |
| 9  | bob lists the keys: he sees only his own. He tries to revoke alice's key by ID, by name, and by ID with the `owner` flag. | 200 / 403 |
| 10 | bob revokes an ID that does not exist. | 200 |
| 11 | The script removes alice from `readAccessToIndex-banana` in LDAP. Her key loses access to banana. | 403 |
| 12 | The script adds alice back. Her key gets access again. | 200 |
| 13 | admin lists all keys and revokes bob's key. | 200 |
| 14 | bob's revoked key stops working at once. | 403 |
| 15 | alice revokes her own key by ID with the `owner` flag, as Kibana does. | 200 / 403 |

The LDAP connector caches the groups for 5 seconds (`cache_ttl` in `confs/readonlyrest.yml`). Thus a group change takes effect after at most 5 seconds.

### Clean up

```bash
./clean.sh
```
