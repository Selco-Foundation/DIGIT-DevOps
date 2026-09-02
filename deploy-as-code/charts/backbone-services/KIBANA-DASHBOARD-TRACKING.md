# Kibana Dashboard View Tracking (POC)

Publishes a "dashboard opened" event to a Kafka topic, using ingress-nginx + Fluent Bit. No custom nginx image, no paid Elasticsearch license required, no per-request Kibana API calls parsed.

This runs **alongside**, not instead of, login tracking (see [`KIBANA-LOGIN-TRACKING.md`](./KIBANA-LOGIN-TRACKING.md)) — separate ingress-nginx plugin, separate Fluent Bit input/filter/output, separate Kafka topic. The login pipeline is untouched.

## Flow

```
Browser opens a dashboard --> ingress-nginx (Lua plugin) --> controller log line
                                                                    |
                                                              Fluent Bit (tail + filter)
                                                                    |
                                                        Kafka topic: kibana-dashboard-events
```

## Why `content_management/rpc/get` + `Referer`, not the dashboard's own URL

Kibana routes a specific dashboard via a URL **fragment**: `.../app/dashboards#/view/<id>`. Fragments are a browser-only concept — they're never sent to any server in the `Referer` header (this is a universal browser restriction, not an nginx limitation). So nginx literally cannot see which dashboard is open, or even tell a specific-dashboard view apart from the plain listing page, by looking at `Referer` alone — both show up identically as `.../app/dashboards`.

What nginx *can* see: the dashboard app fetches each of its panels (visualizations, lens, maps, saved searches) via `POST .../api/content_management/rpc/get`. The **listing page never calls this** — it calls `rpc/search` instead to fetch the list. So `rpc/get` + `Referer` containing `/app/dashboards` reliably means "a specific dashboard is rendering its panels," even though we can't say which one.

This means it tracks *"a dashboard was opened"* only — no dashboard ID, no username. Per-dashboard or per-user breakdown isn't possible with this approach at all (the ID never reaches the server); it would need either Kibana's paid audit logging or a client-side beacon added to the dashboard itself.

**Known gap:** a dashboard made up entirely of markdown/text panels (no visualizations, lens, maps, or saved searches) never calls `rpc/get`, so it won't be detected as "opened." Panel-based dashboards (the vast majority) are covered.

## Files

- `ingress-nginx/files/kibana-dashboard-plugin/main.lua` — new, separate plugin from the login one. `_M.log()` matches `POST .../api/content_management/rpc/get` with a `Referer` containing `/app/dashboards`, debounces per-client via a shared dict, and logs the event.
- `ingress-nginx/templates/kibana-dashboard-plugin-configmap.yaml` — embeds that file into its own ConfigMap (separate from the login plugin's ConfigMap).
- `ingress-nginx/values.yaml` — `controller.config.plugins` now lists both `kibana_login,kibana_dashboard`; added `controller.config.lua-shared-dicts: "kibana_dashboard_events: 1m"` (the dedup memory, only used by this plugin); added a second volume/mount pair alongside the existing login plugin's, so both plugin ConfigMaps get mounted.
- `fluent-bit/values.yaml` — added a second `[INPUT]` (tag `kibana_dashboard`, same log path as the login tail), a second set of `[FILTER]`s (grep for `KIBANA_DASHBOARD_EVENT`, parse the JSON), and a second `[OUTPUT]` (topic `kibana-dashboard-events`) — all matched on the `kibana_dashboard` tag so they run independently of the existing `kibana_login`-tagged pipeline in the same file.

## Debounce logic (why events aren't 1:1 with every panel fetch)

A dashboard with N panels fires N `rpc/get` calls, all within about a second of each other. To avoid one Kafka message per panel:

- The plugin keeps a small in-memory `ngx.shared.DICT` (`kibana_dashboard_events`, declared via `lua-shared-dicts`) — on the first matching request from a client it writes a marker with a 20-second expiry; further matching requests from that client are dropped until it expires.
- Because the dashboard ID itself is invisible to nginx (see above), this can't detect *which* dashboard changed — it's purely time-based. Switching to a different dashboard more than ~20 seconds after the last one is picked up as a new event; switching faster than that, within the same debounce window, isn't.

**Known limitations of this debounce:**
- It's per ingress-nginx controller pod (in-memory, not shared across replicas), and keyed by client IP — multiple users behind the same NAT/proxy IP browsing dashboards around the same time can be undercounted. This is a coarse usage signal, not an exact per-user or per-dashboard count.
- Rapid dashboard-to-dashboard switching (faster than 20s apart) undercounts, since it looks the same as one dashboard's panels loading in a slow burst.

## Why a plugin, not `configuration-snippet`

ingress-nginx already declares `rewrite_by_lua_block`, `header_filter_by_lua_block`, `body_filter_by_lua_block`, and `log_by_lua_block` in every location (to run `plugins.run()`). A snippet can't redeclare any of those without a "duplicate directive" error. The plugin system hooks into the same `plugins.run()` calls instead, so it can use the `log` phase — needed to check the real response status and headers, which aren't fully available in the only free phase (`access`).

Note: this plugin mechanism was removed from ingress-nginx upstream after this controller version (v1.10.0) — don't build much more on it.

## Deploy gotchas

- ingress-nginx's admission-webhook hooks need **cluster-scoped** RBAC (`ClusterRoleBinding`, not `RoleBinding`) to manage its ClusterRole/ClusterRoleBinding on every upgrade.
- `helmfile apply` silently skips the upgrade if it sees no diff — check `helm history <release>` for a new revision, don't trust a green CI run alone.
- A ConfigMap content change alone doesn't restart pods. After changing `main.lua` or Fluent Bit config, run:
  ```
  kubectl rollout restart deployment/ingress-nginx-controller -n backbone-dev
  kubectl rollout restart daemonset/fluent-bit -n backbone-dev
  ```
- `lua-shared-dicts` is a new controller ConfigMap key added for this feature — confirm it lands in the live ingress-nginx ConfigMap after upgrade (`kubectl get cm <controller-cm> -o yaml | grep lua-shared-dicts`), since a missing shared dict makes the plugin silently no-op (`ngx.shared.kibana_dashboard_events` would be `nil`).

## Verify

1. Click into an actual dashboard from the list (landing on the list page alone should NOT trigger anything) → one `KIBANA_DASHBOARD_EVENT` line in controller logs, tagged `main.lua:<line>`.
2. Staying on the same dashboard / letting more panels load → no additional line within 20s (debounced).
3. Navigating to a different dashboard more than 20s later → a new line.
4. Kafka topic `kibana-dashboard-events` shows a matching message: `{event, remote_addr, time, @timestamp}`.

## Known limitations

- No dashboard ID or title — only that *some* dashboard was opened (see "Why `content_management/rpc/get` + `Referer`" above for why the ID is unreachable).
- No username — see the same section above.
- Markdown/text-only dashboards (no panels backed by a saved object) aren't detected.
- Debounce is per-pod, per-client-IP, time-based, best-effort — see "Debounce logic" above.
- `bitnami/fluent-bit` image is paid-only now; chart uses `bitnamilegacy/fluent-bit` as a frozen fallback.
