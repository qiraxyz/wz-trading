--[[
    07_ui.luau
    Tab Main (placeholder) dan tab Trading.
]]

--==================================================
-- MAIN
--==================================================

local MainTab = Window:CreateTab("Main")

MainTab:CreateSection("Main")

MainTab:CreateLabel("Fitur Main akan ditambahkan nanti.", nil, nil, true)

MainTab:CreateLabel("Untuk sekarang semua fitur ada di tab Trading.", nil, nil, true)

--==================================================
-- TRADING
--==================================================

local TradingTab = Window:CreateTab("Trading")

--==================================================
-- WEBHOOK INPUT
--==================================================

TradingTab:CreateSection("Webhook")

for i = 1, 2 do
    Controls.WebhookUrl[i] = TradingTab:CreateInput({
        Name = "Webhook " .. i,
        PlaceholderText = "https://discord.com/api/webhooks/...",
        RemoveTextAfterFocusLost = false,
        Flag = "WebhookURL" .. i,

        Callback = function(Value)
            State.Webhook[i].Url = Trim(Value)
        end
    })
end

local function TestWebhook(index)
    local w = State.Webhook[index]
    local label = "Webhook " .. index

    if Trim(w.Url) == "" then
        Notify("Webhook", label .. " belum diisi.", 3)
        return
    end

    local ok = SendWebhook(w.Url, "Test message from **LioMarket**!")

    Notify("Webhook", ok and (label .. ": terkirim.") or (label .. ": gagal."), 3)
end

TradingTab:CreateButton({
    Name = "Test Webhook 1",
    Callback = function()
        TestWebhook(1)
    end
})

TradingTab:CreateButton({
    Name = "Test Webhook 2",
    Callback = function()
        TestWebhook(2)
    end
})

--==================================================
-- TOGGLE PER WEBHOOK
--==================================================

local function ModeLabel(index)
    local mode = WebhookMode(index)

    if mode == "Off" then
        return "Nonaktif"
    elseif mode == "All" then
        return "Capture All"
    end

    return "Own Booth"
end

for i = 1, 2 do
    TradingTab:CreateSection("Webhook " .. i)

    Controls.OwnBooth[i] = TradingTab:CreateToggle({
        Name = "Own Booth",
        CurrentValue = false,
        Flag = "OwnBooth" .. i,

        Callback = function(Value)
            State.Webhook[i].OwnBooth = Value

            Notify(
                "Webhook " .. i,
                Value and ("Aktif - mode: " .. ModeLabel(i)) or "Nonaktif.",
                3
            )
        end
    })

    Controls.CaptureAll[i] = TradingTab:CreateToggle({
        Name = "Capture All",
        CurrentValue = false,
        Flag = "CaptureAll" .. i,

        Callback = function(Value)
            State.Webhook[i].CaptureAll = Value

            Notify(
                "Webhook " .. i,
                Value and "Mode: Capture All." or ModeLabel(i),
                3
            )
        end
    })
end

--==================================================
-- INFO TAMBAHAN DI PESAN
--==================================================

TradingTab:CreateSection("Message Info")

Controls.ShowCurrentGold = TradingTab:CreateToggle({
    Name = "Show Current Gold",
    CurrentValue = false,
    Flag = "ShowCurrentGold",

    Callback = function(Value)
        State.ShowCurrentGold = Value

        if Value then
            local gold = ReadCurrentGold()

            if gold then
                Notify(
                    "Current Gold",
                    "Gold lu: " .. FormatAngka(gold, State.DecimalSeparator),
                    4
                )
            else
                Notify(
                    "Current Gold",
                    "Label gold belum ketemu. Buka Inventory dulu lalu coba lagi.",
                    5
                )
            end
        end
    end
})

Controls.ShowCoinImage = TradingTab:CreateToggle({
    Name = "Show Coin Image",
    CurrentValue = false,
    Flag = "ShowCoinImage",

    Callback = function(Value)
        State.ShowCoinImage = Value

        if Value then
            local url = ResolveCoinImageUrl()

            if url then
                Notify("Coin Image", "Icon coin akan ditempel di embed.", 4)
            else
                --[[
                    Beri tahu alasannya, bukan cuma "gagal", biar
                    jelas ini soal asset ID, bukan soal webhook.
                ]]
                local label = FindCoinNode(COIN_IMAGE_LABEL)
                local raw = label and label.Image

                if not label then
                    Notify("Coin Image", "ImageLabel belum ketemu. Buka Inventory dulu.", 5)
                elseif type(raw) ~= "string" or Trim(raw) == "" then
                    Notify("Coin Image", "ImageLabel kosong, nggak ada asset untuk dikirim.", 5)
                else
                    Notify(
                        "Coin Image",
                        "Asset \"" .. raw .. "\" bukan rbxassetid, jadi nggak ada URL publik. Embed tetap terkirim tanpa gambar.",
                        6
                    )
                end
            end
        end
    end
})