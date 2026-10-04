--[[
    03_webhook.luau
    Kirim pesan ke Discord webhook.
]]

local function GetRequest()
    if syn and syn.request then
        return syn.request
    end

    if http and http.request then
        return http.request
    end

    if http_request then
        return http_request
    end

    if request then
        return request
    end

    return nil
end

--[[
    SendWebhook(url, message, embed)
    message = teks content (dipakai kalau embed nil)
    embed   = objek embed Discord (dipakai kalau ada)

    Balikin ok, response.
    response dipakai buat lihat body error kalau gagal.
]]
local function SendWebhook(url, message, embed)
    if url == nil or Trim(url) == "" then
        return false
    end

    local requestFunction = GetRequest()
    if not requestFunction then
        return false
    end

    local payload = {}

    if embed then
        -- Kalau embed ada, jangan kirim content juga
        -- supaya informasinya nggak dobel.
        payload.embeds = { embed }
    else
        payload.content = message
    end

    local ok, response = pcall(function()
        return requestFunction({
            Url = Trim(url),
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if not ok or type(response) ~= "table" then
        return false, response
    end

    --[[
        Request executor nggak melempar error pada HTTP 4xx/5xx,
        jadi status wajib dicek manual. Tanpa ini, payload embed
        yang salah (mis. field value kosong) akan dilaporkan
        "terkirim" padahal Discord menolak dengan 400.
    ]]
    if response.Success == false then
        return false, response
    end

    if type(response.StatusCode) == "number" then
        local code = response.StatusCode

        if code < 200 or code > 299 then
            return false, response
        end
    end

    return true, response
end

--[[
    Ambil pesan error singkat dari response webhook,
    buat notify + print kalau gagal.
]]
local function WebhookError(response)
    if type(response) ~= "table" then
        return tostring(response or "tidak diketahui")
    end

    local code = response.StatusCode or "?"
    local body = tostring(response.Body or "")

    if Trim(body) == "" then
        return "HTTP " .. tostring(code)
    end

    return "HTTP " .. tostring(code) .. " - " .. body:sub(1, 300)
end