--[[
    05_message.luau
    Filter transaksi, susun payload, routing per webhook.
]]

--[[
    FilterLolos(mode, sellerName)
    "OwnBooth" -> hanya seller == LocalPlayer
    "All"      -> semua lolos
    "None"/"Off" -> tidak lolos
]]
local function FilterLolos(mode, sellerName)
    if mode == "All" then
        return true
    end

    if mode == "OwnBooth" then
        return sellerName == LocalName
    end

    return false
end

--[[
    Warna embed: emas, biar nyambung sama gold coin.
]]
local EMBED_COLOR_GOLD = 0xF5C518

--[[
    SafeValue(value)
    Discord menolak embed field yang value-nya kosong string
    (HTTP 400). FormatAngka(nil) hasilnya "", jadi semua
    nilai yang masuk embed harus dilewatkan sini.
]]
local function SafeValue(value)
    local text = tostring(value or "")

    if Trim(text) == "" then
        return "-"
    end

    return text
end

local function EmbedField(name, value, inline)
    return {
        name = SafeValue(name),
        value = SafeValue(value),
        inline = inline == true
    }
end

--[[
    BangunPesan(data)

    Balikin dua nilai:
      content = teks markdown, buat print di console
      embed   = objek embed Discord, buat dikirim ke webhook

    Content sengaja nggak ikut dikirim sebagai content karena
    infonya bakal dobel sama embed.
]]
local function BangunPesan(data)
    local suffix = State.GoldSuffix
    local separator = State.DecimalSeparator

    local unitPrice = FormatGold(data.UnitPrice, suffix, separator)
    local total = FormatGold(data.Total, suffix, separator)
    local remaining = FormatGold(data.Remaining, suffix, separator)

    local quantity = FormatAngka(data.Quantity, separator)

    local currentGold = nil

    if data.CurrentGold ~= nil then
        --[[
            FormatAngka (angka raw), bukan FormatGold, supaya
            nggak dapat suffix gold dua kali.
        ]]
        currentGold = FormatAngka(data.CurrentGold, separator) .. " " .. suffix
    end

    --==================================================
    -- Embed Discord
    --==================================================

    local embed = {
        title = "Purchase Detected",
        description = SafeValue(data.Item),
        color = EMBED_COLOR_GOLD,
        fields = {
            EmbedField("Buyer", "`" .. data.Buyer .. "`", true),
            EmbedField("Seller", "`" .. data.Seller .. "`", true),
            EmbedField("Quantity", "`" .. quantity .. "`", true),
            EmbedField("Unit Price", "`" .. unitPrice .. "`", true),
            EmbedField("Total", "`" .. total .. "`", true),
            EmbedField("Remaining", "`" .. remaining .. "`", true)
        }
    }

    if currentGold then
        table.insert(embed.fields, EmbedField("Current Gold", "`" .. currentGold .. "`", true))
    end

    --[[
        Icon gold coin ditaruh di pojok kanan atas embed.
        Kalau asset-nya nggak punya URL publik, fieldnya
        dilewati saja (embed tetap terkirim normal).
    ]]
    if data.CoinImageUrl then
        embed.thumbnail = { url = data.CoinImageUrl }
    end

    --==================================================
    -- Teks console
    --==================================================

    local lines = {
        "**Purchase Detected**",
        "",
        string.format("**Buyer**  : `%s`", data.Buyer),
        string.format("**Seller** : `%s`", data.Seller),
        string.format("**Item**   : `%s`", data.Item),
        "",
        string.format("**Quantity**   : `%s`", quantity),
        string.format("**Unit Price** : `%s`", unitPrice),
        string.format("**Total**      : `%s`", total),
        string.format("**Remaining**  : `%s`", remaining)
    }

    if currentGold then
        table.insert(lines, string.format("**Current Gold** : `%s`", currentGold))
    end

    return table.concat(lines, "\n"), embed
end

--[[
    KirimPesan(pesan, embed, sellerName)
    Tiap webhook punya mode sendiri, jadi routing per webhook.
    results[1] / results[2] = true kalau terkirim.
]]
local function KirimPesan(pesan, embed, sellerName)
    local results = { false, false }

    for i = 1, 2 do
        local w = State.Webhook[i]
        local mode = WebhookMode(i)

        if mode ~= "Off" and Trim(w.Url) ~= "" then
            if FilterLolos(mode, sellerName) then
                local ok, response = SendWebhook(w.Url, pesan, embed)

                if not ok then
                    --[[
                        Payload embed yang salah (mis. URL gambar
                        nggak valid) ditolak Discord tanpa error
                        Luau, jadi detailnya ikut dicetak.
                    ]]
                    warn("[LioMarket] Webhook " .. i .. " gagal: " .. WebhookError(response))
                end

                results[i] = ok
            end
        end
    end

    return results
end