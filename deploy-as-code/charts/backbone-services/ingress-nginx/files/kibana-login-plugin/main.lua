local ngx = ngx
local cjson = require "cjson.safe"

local _M = {}

local LOGIN_URI = "/kibana/internal/security/login"

function _M.access()
    if ngx.var.uri ~= LOGIN_URI or ngx.req.get_method() ~= "POST" then
        return
    end

    ngx.req.read_body()
    local body = cjson.decode(ngx.req.get_body_data() or "")

    if body and body.params and body.params.username then
        ngx.ctx.kibana_login_username = body.params.username
    end
end

function _M.log()
    if ngx.var.uri ~= LOGIN_URI or ngx.req.get_method() ~= "POST" then
        return
    end

    if ngx.status ~= 200 then
        return
    end

    local username = ngx.ctx.kibana_login_username
    if not username then
        return
    end

    local event = cjson.encode({
        event = "kibana_login",
        username = username,
        remote_addr = ngx.var.remote_addr,
        time = ngx.time(),
    })

    ngx.log(ngx.NOTICE, "KIBANA_LOGIN_EVENT " .. event)
end

return _M
