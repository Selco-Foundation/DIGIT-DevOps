local ngx = ngx

local _M = {}

-- content_management rpc/get is how a dashboard fetches its panels
-- (visualizations, lens, maps, saved searches, ...). The dashboards LIST page
-- never calls this (it calls rpc/search instead), so rpc/get + being on the
-- dashboards app is a reliable "a specific dashboard is rendering" signal.
--
-- We can't key off the dashboard ID itself: Kibana routes dashboards via a
-- URL fragment (#/view/<id>), and browsers never send the fragment in the
-- Referer header to any server, so nginx has no visibility into which
-- dashboard it is - only that some dashboard is open.
local RPC_GET_URI_PATTERN = [[^/kibana(/s/[^/]+)?/api/content_management/rpc/get$]]
local DASHBOARDS_REFERER_PATTERN = [[/app/dashboards]]

-- A single dashboard open fires one rpc/get per panel, all within ~1s of
-- each other. This collapses that burst into a single event per client,
-- while still letting a later, distinct visit count again.
local DEBOUNCE_TTL = 20

function _M.log()
    if ngx.status ~= 200 or ngx.req.get_method() ~= "POST" then
        return
    end

    if not ngx.re.find(ngx.var.uri, RPC_GET_URI_PATTERN, "jo") then
        return
    end

    local referer = ngx.var.http_referer
    if not referer or not ngx.re.find(referer, DASHBOARDS_REFERER_PATTERN, "jo") then
        return
    end

    local dict = ngx.shared.kibana_dashboard_events
    if not dict then
        return
    end

    local client = ngx.var.remote_addr
    local ok = dict:add(client, true, DEBOUNCE_TTL)
    if not ok then
        return
    end

    local event = string.format(
        '{"event":"kibana_dashboard_view","remote_addr":"%s","time":%d}',
        client, ngx.time()
    )

    ngx.log(ngx.NOTICE, "KIBANA_DASHBOARD_EVENT " .. event)
end

return _M
