# Kibana Login Tracking (POC)

Publishes successful Kibana logins (username) to a Kafka topic, using ingress-nginx + Fluent Bit. No custom nginx image, no paid Elasticsearch license required.

## Flow

```
Browser login --> ingress-nginx (Lua plugin) --> controller log line
                                                        |
                                                  Fluent Bit (tail + filter)
                                                        |
                                              Kafka topic: kibana-login-events
```

The plugin captures the username on the login request, and only emits a log line if the response is `200`. Fluent Bit tails the controller's log, keeps only matching lines, extracts the JSON, and produces it to Kafka.

## Files

- `ingress-nginx/files/kibana-login-plugin/main.lua` — the plugin. `_M.rewrite()` grabs the username from the login POST body; `_M.log()` logs the event only on `ngx.status == 200`.
- `ingress-nginx/templates/kibana-login-plugin-configmap.yaml` — embeds that file into a ConfigMap.
- `ingress-nginx/values.yaml` — `controller.config.plugins: "kibana_login"` + volume/mount for the ConfigMap.
- `fluent-bit/` — new chart. Tails `*ingress-nginx-controller*.log`, filters for `KIBANA_LOGIN_EVENT`, parses out the JSON, produces to Kafka.
- `kibana/values.yaml` — no custom annotations needed; all logic lives in the plugin.

## Why a plugin, not `configuration-snippet`

ingress-nginx already declares `rewrite_by_lua_block`, `header_filter_by_lua_block`, `body_filter_by_lua_block`, and `log_by_lua_block` in every location (to run `plugins.run()`). A snippet can't redeclare any of those without a "duplicate directive" error. The plugin system hooks into the same `plugins.run()` calls instead, so it can use the `log` phase — needed to check the real response status, which isn't known yet in the only free phase (`access`).

Note: this plugin mechanism was removed from ingress-nginx upstream after this controller version (v1.10.0) — don't build much more on it.

## Deploy gotchas

- ingress-nginx's admission-webhook hooks need **cluster-scoped** RBAC (`ClusterRoleBinding`, not `RoleBinding`) to manage its ClusterRole/ClusterRoleBinding on every upgrade.
- `helmfile apply` silently skips the upgrade if it sees no diff — check `helm history <release>` for a new revision, don't trust a green CI run alone.
- A ConfigMap content change alone doesn't restart pods. After changing `main.lua` or Fluent Bit config, run:
  ```
  kubectl rollout restart deployment/ingress-nginx-controller -n backbone-dev
  kubectl rollout restart daemonset/fluent-bit -n backbone-dev
  ```

## Verify

1. Failed login → no `KIBANA_LOGIN_EVENT` in controller logs.
2. Successful login → one `KIBANA_LOGIN_EVENT` line, tagged `main.lua:<line>`.
3. Kafka topic `kibana-login-events` shows a matching message: `{event, username, remote_addr, time, @timestamp}`.

## Known limitations

- Only `username`, no display name (would need a second call/correlation to `/kibana/internal/security/me`).
- Failed logins aren't tracked at all (by design, for now).
- `bitnami/fluent-bit` image is paid-only now; chart uses `bitnamilegacy/fluent-bit` as a frozen fallback.
