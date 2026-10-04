local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Window = Rayfield:CreateWindow({
    Name = "My Script Hub",
    LoadingTitle = "My Script Hub",
    LoadingSubtitle = "Trading Menu",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MyScriptHub",
        FileName = "Config"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

--==================================================
-- VARIABLES
--==================================================

local WebhookURL1 = ""
local WebhookURL2 = ""
local DetectFeature1 = false
local DetectFeature2 = false
local LastNotification = 0
local Cooldown = 2
local FilterMode = "OwnBooth" -- "OwnBooth", "All", "None"
local CaptureTarget = "All" -- "Webhook 1", "Webhook 2", "All", "None"

--==================================================
-- WEBHOOK
--==================================================

local function SendWebhook(url, message)
    if url == "" then
        return false
    end

    local requestFunction =
        (syn and syn.request)
        or (http and http.request)
        or http_request
        or request

    if not requestFunction then
        return false
    end

    local success, response = pcall(function()
        return requestFunction({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                content = message
            })
        })
    end)

    if not success then
        return false
    end

    return true
end

--==================================================
-- MAIN TAB
--==================================================

local MainTab = Window:CreateTab("Main")

MainTab:CreateSection("Webhook")

MainTab:CreateInput({
    Name = "Webhook 1",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Flag = "WebhookURL1",

    Callback = function(Value)
        WebhookURL1 = Value
    end
})

MainTab:CreateInput({
    Name = "Webhook 2",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false,
    Flag = "WebhookURL2",

    Callback = function(Value)
        WebhookURL2 = Value
    end
})

MainTab:CreateButton({
    Name = "Test Webhook 1",
    Callback = function()
        if WebhookURL1 == "" then
            Rayfield:Notify({
                Title = "Webhook",
                Content = "Webhook 1 belum diisi.",
                Duration = 3
            })
            return
        end

        local success = SendWebhook(WebhookURL1, "Test message from Roblox!")

        Rayfield:Notify({
            Title = "Webhook",
            Content = success
                and "Test message sent!"
                or "Failed to send message.",
            Duration = 3
        })
    end
})

MainTab:CreateButton({
    Name = "Test Webhook 2",
    Callback = function()
        if WebhookURL2 == "" then
            Rayfield:Notify({
                Title = "Webhook",
                Content = "Webhook 2 belum diisi.",
                Duration = 3
            })
            return
        end

        local success = SendWebhook(WebhookURL2, "Test message from Roblox!")

        Rayfield:Notify({
            Title = "Webhook",
            Content = success
                and "Test message sent!"
                or "Failed to send message.",
            Duration = 3
        })
    end
})

--==================================================
-- TRADING DETECTION
--==================================================

MainTab:CreateSection("Purchase Detection")

MainTab:CreateToggle({
    Name = "Webhook 1 - Purchase Detection",
    CurrentValue = false,
    Flag = "PurchaseDetection1",

    Callback = function(Value)
        DetectFeature1 = Value
        if not Value and FilterMode == "All" then
            if not DetectFeature2 then
                FilterMode = "OwnBooth"
                Rayfield:Notify({
                    Title = "Capture Mode",
                    Content = "Capture All dimatikan karena tidak ada webhook aktif.",
                    Duration = 3
                })
            end
        end

        Rayfield:Notify({
            Title = "Purchase Detection",
            Content = Value
                and "Webhook 1 enabled."
                or "Webhook 1 disabled.",
            Duration = 3
        })
    end
})

MainTab:CreateToggle({
    Name = "Webhook 2 - Purchase Detection",
    CurrentValue = false,
    Flag = "PurchaseDetection2",

    Callback = function(Value)
        DetectFeature2 = Value
        if not Value and FilterMode == "All" then
            if not DetectFeature1 then
                FilterMode = "OwnBooth"
                Rayfield:Notify({
                    Title = "Capture Mode",
                    Content = "Capture All dimatikan karena tidak ada webhook aktif.",
                    Duration = 3
                })
            end
        end

        Rayfield:Notify({
            Title = "Purchase Detection",
            Content = Value
                and "Webhook 2 enabled."
                or "Webhook 2 disabled.",
            Duration = 3
        })
    end
})

MainTab:CreateDropdown({
    Name = "Capture Mode",
    Options = {"OwnBooth", "All", "None"},
    CurrentOption = "OwnBooth",
    Flag = "CaptureMode",
    Callback = function(Option)
        if Option == "All" then
            if not DetectFeature1 and not DetectFeature2 then
                Rayfield:Notify({
                    Title = "Capture Mode",
                    Content = "Tidak bisa capture all jika tidak ada webhook aktif.",
                    Duration = 3
                })
                return
            end
            FilterMode = "All"
        elseif Option == "None" then
            FilterMode = "None"
        else
            FilterMode = "OwnBooth"
        end

        Rayfield:Notify({
            Title = "Capture Mode",
            Content = FilterMode == "OwnBooth" and "Hanya pembelian ke booth LocalPlayer" or FilterMode == "All" and "Mengambil SEMUA data pembelian" or "Tidak mengambil data",
            Duration = 3
        })
    end
})

MainTab:CreateDropdown({
    Name = "Capture Target",
    Options = {"Webhook 1", "Webhook 2", "All", "None"},
    CurrentOption = "All",
    Flag = "CaptureTarget",
    Callback = function(Option)
        CaptureTarget = Option

        if CaptureTarget == "Webhook 1" and not DetectFeature1 then
            Rayfield:Notify({
                Title = "Capture Target",
                Content = "Webhook 1 belum aktif. Nyalakan toggle dulu.",
                Duration = 3
            })
            return
        end

        if CaptureTarget == "Webhook 2" and not DetectFeature2 then
            Rayfield:Notify({
                Title = "Capture Target",
                Content = "Webhook 2 belum aktif. Nyalakan toggle dulu.",
                Duration = 3
            })
            return
        end

        if CaptureTarget == "All" and not DetectFeature1 and not DetectFeature2 then
            Rayfield:Notify({
                Title = "Capture Target",
                Content = "Tidak ada webhook yang aktif.",
                Duration = 3
            })
            return
        end

        Rayfield:Notify({
            Title = "Capture Target",
            Content = Option == "All" and "Kirim ke semua webhook" or Option == "None" and "Tidak kirim ke webhook" or ("Kirim ke " .. Option),
            Duration = 3
        })
    end
})

--==================================================
-- SHOP PURCHASED EVENT
--==================================================

local PurchaseEvent = ReplicatedStorage
    :WaitForChild("Remotes")
    :WaitForChild("Shop_PurchasedFromShop")

-- Kemungkinan args[1] bukan buyer yang sebenarnya.
-- Gunakan args[2] yang pada event contoh adalah LocalPlayer.

-- Intinya: jangan cek args[1] atau args[2].
-- Ambil nama Buyer, lalu hanya lanjut kalau Buyer == LocalPlayer.Name.

PurchaseEvent.OnClientEvent:Connect(function(...)
    if not DetectFeature1 and not DetectFeature2 then
        return
    end

    local args = {...}

    if #args < 6 then
        return
    end

    local buyer = args[1]
    local seller = args[2]
    local item = args[3]
    local quantity = args[4]
    local price = args[5]
    local remaining = args[6]

    -- Ambil nama buyer
    local buyerName

    if typeof(buyer) == "Instance" and buyer:IsA("Player") then
        buyerName = buyer.Name
    elseif type(buyer) == "string" then
        buyerName = buyer
    else
        return
    end

    -- Ambil nama seller
    local sellerName

    if typeof(seller) == "Instance" and seller:IsA("Player") then
        sellerName = seller.Name
    elseif type(seller) == "string" then
        sellerName = seller
    else
        return
    end

    -- Filter berdasarkan pengaturan
    if FilterMode == "None" then
        return
    elseif FilterMode == "All" then
        -- Izinkan semua data
    elseif FilterMode == "OwnBooth" then
        if sellerName ~= LocalPlayer.Name then
            return
        end
    end

    local itemName = "Unknown"

    if typeof(item) == "Instance" then
        itemName = item.Name
    elseif item ~= nil then
        itemName = tostring(item)
    end

    local message = string.format(
        "**Purchase Detected**\n" ..
        "Buyer: `%s`\n" ..
        "Seller: `%s`\n" ..
        "Item: `%s`\n" ..
        "Quantity: `%s`\n" ..
        "Price: `%s`\n" ..
        "Remaining: `%s`",
        buyerName,
        sellerName,
        itemName,
        tostring(quantity),
        tostring(price),
        tostring(remaining)
    )

    print(message)

    if CaptureTarget == "None" then
        -- Tidak kirim kemana-mana
    elseif CaptureTarget == "Webhook 1" then
        if DetectFeature1 then
            SendWebhook(WebhookURL1, message)
        end
    elseif CaptureTarget == "Webhook 2" then
        if DetectFeature2 then
            SendWebhook(WebhookURL2, message)
        end
    elseif CaptureTarget == "All" then
        if DetectFeature1 then
            SendWebhook(WebhookURL1, message)
        end
        if DetectFeature2 then
            SendWebhook(WebhookURL2, message)
        end
    end

    Rayfield:Notify({
        Title = "Purchase Detected",
        Content = string.format(
            "%s bought %s x%s",
            buyerName,
            itemName,
            tostring(quantity)
        ),
        Duration = 5
    })
end)
--==================================================
-- SETTINGS
--==================================================

local MiscTab = Window:CreateTab("Misc")

MiscTab:CreateSection("Misc")

MiscTab:CreateButton({
    Name = "Destroy Script",
    Callback = function()
        Rayfield:Destroy()
    end
})

local SettingsTab = Window:CreateTab("Settings")

SettingsTab:CreateSection("UI Settings")

SettingsTab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightShift",
    HoldToInteract = false,
    Flag = "ToggleUI",

    Callback = function()
        Rayfield:Toggle()
    end
})

Rayfield:LoadConfiguration()