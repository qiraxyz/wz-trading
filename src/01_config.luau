--[[
    01_config.luau
    Services, Rayfield window, dan state global.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
    LocalName dipakai untuk:
    - filter OwnBooth (seller harus == LocalName)
    - mengisi field Seller saat yang jual booth sendiri
]]
local LocalPlayer = Players.LocalPlayer
local LocalName = LocalPlayer.Name

local RAYFIELD_URL = "https://sirius.menu/rayfield"

local Rayfield = loadstring(game:HttpGet(RAYFIELD_URL))()

local Window = Rayfield:CreateWindow({
    Name = "LioMarket",
    LoadingTitle = "LioMarket",
    LoadingSubtitle = "Purchase Detection Helper",
    ConfigurationSaving = {
        --[[
            Dimatikan karena kita pakai config sendiri (06_config_io.luau).
            Config Rayfield pakai Flag yang sama dan load-nya async
            (task.spawn), jadi kalau dua-duanya nyala bisa saling clobber.
        ]]
        Enabled = false,
        FolderName = "LioMarket",
        FileName = "Config"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

--==================================================
-- STATE
--==================================================

local State = {
    --[[
        Per webhook:
          Url         -> discord webhook url
          OwnBooth    -> filter: hanya seller == LocalPlayer
          CaptureAll  -> filter: semua transaksi

        Keduanya pure filter, bukan master switch.
        Dua-duanya mati  -> tidak ada yang dikirim ("Off")
        OwnBooth saja    -> "OwnBooth"
        CaptureAll       -> "All" (menang kalau dua-duanya nyala)
    ]]
    Webhook = {
        [1] = { Url = "", OwnBooth = false, CaptureAll = false },
        [2] = { Url = "", OwnBooth = false, CaptureAll = false }
    },

    GoldSuffix = "gold",
    DecimalSeparator = ".",

    --[[
        Tampilkan sisa gold lu di pesan webhook.
        Butuh UI game sudah kebaca (CoinDisplay).
    ]]
    ShowCurrentGold = false,

    --[[
        Tempelkan icon gold coin ke embed webhook.
        Hanya bisa kalau ImageLabel pakai rbxassetid://
        (texture bawaan engine nggak punya URL publik).
    ]]
    ShowCoinImage = false,

    RemotePath = { "Remotes", "Shop_PurchasedFromShop" },

    -- Config
    ConfigFolder = "LioMarket/configs",
    ConfigNameInput = "",
    SelectedConfig = nil,
    ConfigList = {},

    -- Autoload config
    AutoloadDir = "LioMarket",
    AutoloadFile = "autoload.txt",
    AutoloadConfig = nil
}

--[[
    Sentinel untuk dropdown saat belum ada config sama sekali.
]]
local NO_CONFIG = "(Belum ada config)"

--[[
    Sentinel saat config ada tapi belum ada yang dipilih.
    Dipakai sebagai option paling atas supaya tidak auto-select
    config pertama (bisa salah delete).
]]
local PICK_CONFIG = "(Pilih config)"

--[[
    Controls = referensi value object UI Rayfield.
    Dipakai buat restore nilai config ke tampilan.
]]
local Controls = {
    WebhookUrl = {},
    OwnBooth = {},
    CaptureAll = {},
    GoldSuffix = nil,
    DecimalSeparator = nil,
    ShowCurrentGold = nil,
    ShowCoinImage = nil,
    ToggleUI = nil,
    ConfigNameInput = nil,
    ConfigDropdown = nil,
    AutoloadLabel = nil
}

--[[
    WebhookMode(index) -> "Off" | "OwnBooth" | "All"
    Sumber kebenaran tunggal untuk mode tiap webhook.

    Prioritas: CaptureAll menang kalau dua filter nyala.
]]
local function WebhookMode(index)
    local w = State.Webhook[index]

    if not w then
        return "Off"
    end

    if w.CaptureAll then
        return "All"
    end

    if w.OwnBooth then
        return "OwnBooth"
    end

    return "Off"
end

local function AutoloadPath()
    return State.AutoloadDir .. "/" .. State.AutoloadFile
end

local Notify = function(Title, Content, Duration)
    Rayfield:Notify({
        Title = Title,
        Content = Content,
        Duration = Duration or 3
    })
end