--[[
    liomarket.luau
    Auto-generated. Edit src/*.luau lalu run: .\build.ps1
]]

--==================================================
-- 01_config.luau
--==================================================
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

--==================================================
-- 02_utils.luau
--==================================================
--[[
    02_utils.luau
    Helper umum: filesystem, format angka, resolusi nama.
]]

--[[
    HasFileAPI()
   true kalau executor mendukung writefile / readfile / isfile.
]]
local function HasFileAPI()
    return type(writefile) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
end

--[[
    EnsureDir(dir)
    Bikin folder kalau belum ada.
]]
local function EnsureDir(dir)
    if type(isfolder) == "function" and isfolder(dir) then
        return true
    end

    if type(makefolder) ~= "function" then
        return false
    end

    --[[
        Bikin parent dulu supaya path bersarang aman di executor
        yang makefolder tidak rekursif. Satu segmen dilepas per
        panggilan, jadi rekursi ini pasti berhenti.
    ]]
    local parent = tostring(dir):match("^(.+)[/\\][^/\\]+$")

    if parent and parent ~= dir then
        EnsureDir(parent)
    end

    return pcall(makefolder, dir) == true
end

local function Trim(value)
    return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

--[[
    FormatAngka(40000) -> "40.000"
]]
local function FormatAngka(nilai, separator)
    separator = separator or "."

    local teks = tostring(nilai)

    -- Buang karakter non-digit (koma, spasi, newline, dll)
    teks = teks:gsub("[^%d%-]", "")

    local negatif = teks:sub(1, 1) == "-"
    if negatif then
        teks = teks:sub(2)
    end

    -- Pisahkan bagian desimal kalau ada
    local bulat, desimal = teks:match("^(%d+)%.(%d+)$")
    bulat = bulat or teks

    -- Sisipkan separator tiap 3 digit dari kanan
    local hasil = ""

    for i = 1, #bulat do
        if i > 1 and (#bulat - i + 1) % 3 == 0 then
            hasil = hasil .. separator
        end

        hasil = hasil .. bulat:sub(i, i)
    end

    if desimal then
        hasil = hasil .. "," .. desimal
    end

    if negatif then
        hasil = "-" .. hasil
    end

    return hasil
end

--[[
    FormatGold(nilai) -> "40.000 gold"
]]
local function FormatGold(nilai, suffix, separator)
    suffix = suffix or "gold"

    if nilai == nil then
        return "Unknown"
    end

    local angka = tonumber(nilai)
    if not angka then
        return FormatAngka(nilai, separator) .. " " .. suffix
    end

    return FormatAngka(angka, separator) .. " " .. suffix
end

--[[
    ResolveName(value)
    Terima Instance atau string, return nama string.
    Return nil kalau tipe gak dikenal.
]]
local function ResolveName(value)
    if value == nil then
        return nil
    end

    if typeof(value) == "Instance" then
        return value.Name
    end

    if type(value) == "string" then
        local bersih = Trim(value)
        if bersih == "" then
            return nil
        end

        return bersih
    end

    return nil
end

--[[
    ResolveItemName(value)
]]
local function ResolveItemName(value)
    if value == nil then
        return "Unknown"
    end

    if typeof(value) == "Instance" then
        local nama = value.Name
        if nama == "" then
            return "Unknown"
        end

        return nama
    end

    if type(value) == "string" then
        local bersih = Trim(value)
        if bersih == "" then
            return "Unknown"
        end

        return bersih
    end

    return tostring(value)
end

--==================================================
-- CURRENT GOLD
--==================================================

--[[
    Path dari PlayerGui ke gold coin:
    PlayerGui.Inventory.Inventory.CoinDisplay.AmountLabel
    PlayerGui.Inventory.Inventory.CoinDisplay.ImageLabel

    Bisa belum ada saat script jalan (UI masih loading),
    dan bisa di-recreate kalau player respawn,
    jadi dicari ulang tiap baca.
]]
local COIN_PATH = { "Inventory", "Inventory", "CoinDisplay" }
local COIN_AMOUNT_LABEL = "AmountLabel"
local COIN_IMAGE_LABEL = "ImageLabel"

local goldLabel = nil
local goldCache = nil
local coinImageLabel = nil
local coinImageUrl = nil

--[[
    Cari node di bawah PlayerGui lewat daftar path.
]]
local function FindCoinNode(name)
    local gui = LocalPlayer:FindFirstChild("PlayerGui")

    if not gui then
        return nil
    end

    local node = gui

    for _, step in ipairs(COIN_PATH) do
        node = node:FindFirstChild(step)

        if not node then
            return nil
        end
    end

    return node:FindFirstChild(name)
end

local GOLD_MULTIPLIER = {
    k = 1e3,
    m = 1e6,
    b = 1e9,
    t = 1e12
}

--[[
    ParseGoldText(text)
    Terima "1234567", "1.234.567", "1,234,567", "1.234.567 Gold",
    dan singkatan "1.5M" / "1,234K".

    Dua cara baca, dibedakan oleh ada/tidaknya huruf pengali:

      -ada pengali  -> titik = desimal, jadi koma aja yang dibuang
      -tanpa pengali-> titik & koma = separator ribuan, jadi semua
                      non-digit dibuang

    Balikin nil kalau tidak bisa dipastikan, supaya lebih baik
    nggak tampil daripada tampil angka yang salah.
]]
local function ParseGoldText(text)
    local s = Trim(text)

    if s == "" then
        return nil
    end

    --[[
        Ambil satu token saja supaya satuan di belakang
        ("Gold", "coin") nggak ikut diparse.
    ]]
    s = s:match("^(%S+)") or s

    local multiplier = 1
    local numPart, multPart = s:match("^(.-)([kKmMbBtT])$")

    if numPart then
        local m = GOLD_MULTIPLIER[multPart:lower()]

        -- Pengali dikenal tapi angkanya bukan angka -> jangan ditebak
        if not m then
            return nil
        end

        multiplier = m
        s = numPart:gsub("[,%s]", "")
    else
        s = s:gsub("[^%d]", "")
    end

    local value = tonumber(s)

    if not value then
        return nil
    end

    return value * multiplier
end

local function GetGoldLabel()
    if goldLabel and goldLabel.Parent then
        return goldLabel
    end

    goldLabel = FindCoinNode(COIN_AMOUNT_LABEL)

    return goldLabel
end

local function GetCoinImageLabel()
    if coinImageLabel and coinImageLabel.Parent then
        return coinImageLabel
    end

    coinImageLabel = FindCoinNode(COIN_IMAGE_LABEL)

    --[[
        Asset bisa berubah (ganti icon), jadi cache URL
        harus dibuang saat label ditemukan ulang.
    ]]
    coinImageUrl = nil

    return coinImageLabel
end

--[[
    ResolveCoinImageUrl()
    Ubah ImageLabel.Image jadi URL PNG publik yang bisa di-fetch
    Discord.

    Roblox nggak bisa upload gambar lokal ke Discord, jadi satu-satunya
    cara adalah bikin URL publik dari asset ID:

        https://assetdelivery.roblox.com/v1/asset/?id=<ID>&width=..&format=Png

    Balikin nil kalau:
      - ImageLabel belum ada
      - Image kosong / bukan string
      - Image bukan rbxassetid:// (mis. rbxasset://textures/...,
        texture bawaan engine yang nggak punya URL publik)

    Hasil di-cache supayaga nggak request ulang tiap transaksi.
]]
local function ResolveCoinImageUrl()
    if coinImageUrl then
        return coinImageUrl
    end

    local label = GetCoinImageLabel()

    if not label then
        return nil
    end

    local raw = label.Image

    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local id = raw:match("rbxassetid://(%d+)")

    if not id then
        return nil
    end

    coinImageUrl = "https://assetdelivery.roblox.com/v1/asset/?id=" .. id
        .. "&width=128&height=128&format=Png"

    return coinImageUrl
end

--[[
    ReadCurrentGold()
    Balikin angka gold lu, atau nil kalau label belum siap.
    Nilai terakhir yang berhasil dibaca disimpan sebagai cache
    supaya satu frame yang gagal baca nggak bikin info kosong.
]]
local function ReadCurrentGold()
    local label = GetGoldLabel()

    if not label then
        return goldCache
    end

    local ok, text = pcall(function()
        return label.Text
    end)

    if ok and type(text) == "string" then
        local value = ParseGoldText(text)

        if value then
            goldCache = value
        end
    end

    return goldCache
end

--[[
    Hangatkan cache di background supaya saat transaksi pertama
    arrives, label biasanya sudah ketemu.
]]
task.spawn(function()
    ReadCurrentGold()

    while LocalPlayer.Parent do
        task.wait(10)

        if State.ShowCurrentGold then
            ReadCurrentGold()
        end

        --[[
            URL coin di-cache, jadi cukup pastikan label-nya
            masih hidup. Kalau label hilang, cache URL ikut dibuang
            biar asset berikutnya dicari ulang.
        ]]
        if State.ShowCoinImage and coinImageUrl and not GetCoinImageLabel() then
            coinImageUrl = nil
        end
    end
end)

--==================================================
-- 03_webhook.luau
--==================================================
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

--==================================================
-- 04_config_io.luau
--==================================================
--[[
    04_config_io.luau
    Config manager: create / list / select / load / delete / reset,
    plus autoload pointer ke salah satu saved config.

    Autoload di sini BUKAN autoload source script.
    File autoload cuma berisi nama config yang mau auto-load
    setiap script dijalankan.

    HasFileAPI / EnsureDir ada di 02_utils.luau.
]]

--[[
    Nama config: hanya huruf (A-Z / a-z).
    Non-huruf dibuang supaya nama aman buat path.
]]
local function SanitizeName(raw)
    local bersih = Trim(raw):gsub("[^%a]", "")

    if bersih == "" then
        return nil
    end

    return bersih
end

local function ConfigDir()
    return State.ConfigFolder
end

local function ConfigPath(name)
    return ConfigDir() .. "/" .. name .. ".json"
end

--[[
    Daftar nama config yang ada, urut alfabetis.
]]
local function ListConfigs()
    local hasil = {}

    if not HasFileAPI() then
        return hasil
    end

    if type(isfolder) == "function" and not isfolder(ConfigDir()) then
        return hasil
    end

    local ok, files = pcall(function()
        return listfiles and listfiles(ConfigDir() .. "/") or {}
    end)

    if not ok or type(files) ~= "table" then
        return hasil
    end

    for _, path in pairs(files) do
        local nama = path:match("([^/\\]+)%.json$")

        if nama and SanitizeName(nama) == nama then
            table.insert(hasil, nama)
        end
    end

    table.sort(hasil)

    return hasil
end

--[[
    Isi dropdown: kalau ada config, tambahkan "(Pilih config)"
    di atas supaya tidak auto-select config pertama.
]]
local function DropdownOptions()
    if #State.ConfigList == 0 then
        return { NO_CONFIG }
    end

    local options = { PICK_CONFIG }

    for _, nama in ipairs(State.ConfigList) do
        table.insert(options, nama)
    end

    return options
end

--[[
    Refresh isi dropdown + samakan tampilan dengan SelectedConfig.
    Refresh tidak memicu callback dan tidak update teks dropdown,
    jadi harus:Set() setelahnya.
]]
local function SyncDropdown()
    local dropdown = Controls.ConfigDropdown

    if not dropdown then
        return
    end

    local options = DropdownOptions()
    dropdown:Refresh(options)

    local target = options[1]

    if State.SelectedConfig then
        for _, nama in pairs(options) do
            if nama == State.SelectedConfig then
                target = nama
                break
            end
        end
    end

    dropdown:Set(target)
end

--[[
    Sinkronkan State.ConfigList + isi dropdown UI.
]]
local function RefreshConfigList()
    State.ConfigList = ListConfigs()

    -- Pastikan SelectedConfig masih valid
    if State.SelectedConfig then
        local masihAda = false

        for _, nama in pairs(State.ConfigList) do
            if nama == State.SelectedConfig then
                masihAda = true
                break
            end
        end

        if not masihAda then
            State.SelectedConfig = nil
        end
    end

    SyncDropdown()

    return State.ConfigList
end

--[[
    Config terpilih. Kalau belum ada, notify + return nil.
]]
local function RequireSelected(action)
    local name = State.SelectedConfig

    if not name or name == NO_CONFIG or name == PICK_CONFIG then
        Notify("Config", "Pilih config di Config List dulu (" .. action .. ").", 4)
        return nil
    end

    if not HasFileAPI() then
        Notify("Config", "Executor tidak punya file API.", 4)
        return nil
    end

    if not isfile(ConfigPath(name)) then
        Notify("Config", "Config \"" .. name .. "\" tidak ada.", 4)
        State.SelectedConfig = nil
        RefreshConfigList()
        return nil
    end

    return name
end

--[[
    Kumpulkan state saat ini jadi tabel JSON.
]]
local function Kumpulkan()
    return {
        version = 2,
        savedAt = os.time(),

        webhook1 = {
            url = State.Webhook[1].Url,
            ownBooth = State.Webhook[1].OwnBooth,
            captureAll = State.Webhook[1].CaptureAll
        },
        webhook2 = {
            url = State.Webhook[2].Url,
            ownBooth = State.Webhook[2].OwnBooth,
            captureAll = State.Webhook[2].CaptureAll
        },

        goldSuffix = State.GoldSuffix,
        decimalSeparator = State.DecimalSeparator,
        showCurrentGold = State.ShowCurrentGold,
        showCoinImage = State.ShowCoinImage,

        toggleUI = Controls.ToggleUI and Controls.ToggleUI.CurrentKeybind or "RightShift"
    }
end

--[[
    Terapkan config ke UI (lewat :Set() supaya State ikut update).
]]
local function Terapkan(data)
    if type(data) ~= "table" then
        return false, "Isi config bukan table."
    end

    for i = 1, 2 do
        local w = data["webhook" .. i]

        if type(w) == "table" then
            if w.url ~= nil then
                Controls.WebhookUrl[i]:Set(tostring(w.url))
            end

            --[[
                Backward compatibility: config lama pakai "detect"
                (dulu master switch, sekarang jadi filter Own Booth).
            ]]
            local ownBooth = w.ownBooth

            if ownBooth == nil then
                ownBooth = w.detect
            end

            if w.captureAll ~= nil then
                Controls.CaptureAll[i]:Set(w.captureAll == true)
            end

            if ownBooth ~= nil then
                Controls.OwnBooth[i]:Set(ownBooth == true)
            end
        end
    end

    if data.goldSuffix ~= nil then
        Controls.GoldSuffix:Set(tostring(data.goldSuffix))
    end

    if data.decimalSeparator ~= nil then
        Controls.DecimalSeparator:Set(tostring(data.decimalSeparator))
    end

    if data.showCurrentGold ~= nil and Controls.ShowCurrentGold then
        Controls.ShowCurrentGold:Set(data.showCurrentGold == true)
    end

    if data.showCoinImage ~= nil and Controls.ShowCoinImage then
        Controls.ShowCoinImage:Set(data.showCoinImage == true)
    end

    --[[
        Enum.KeyCode[key] mengembalikan nil untuk nama key yang
        tidak dikenal (tidak error), jadi hasil pcall HARUS
        dicek dua-duanya.
    ]]
    if data.toggleUI ~= nil and Controls.ToggleUI then
        local key = tostring(data.toggleUI)

        if key == "Unknown" then
            key = "RightShift"
        end

        local ok, code = pcall(function()
            return Enum.KeyCode[key]
        end)

        if ok and code ~= nil then
            Controls.ToggleUI:Set(key)
        end
    end

    return true
end

--==================================================
-- CRUD
--==================================================

--[[
    Create config baru dari isi input.
    Input kosong / non-huruf -> invalid.
    Nama yang sudah dipakai -> ditolak, harus pakai Overwrite.
]]
local function ConfigCreate()
    if not HasFileAPI() then
        return false, "Executor tidak punya writefile/readfile/isfile."
    end

    local name = SanitizeName(State.ConfigNameInput)

    if not name then
        return false, "Isi Config Name dulu (huruf saja)."
    end

    if not EnsureDir(ConfigDir()) then
        return false, "Gagal membuat folder: " .. ConfigDir()
    end

    local path = ConfigPath(name)

    --[[
        Create tidak boleh menimpa. Overwrite harus lewat
        Overwrite Config pada config yang terpilih, supaya
        tidak ada file yang hilang tanpa sengaja.
    ]]
    if isfile(path) then
        return false, "Config \"" .. name .. "\" sudah ada. Pilih di Config List lalu pakai Overwrite Config."
    end

    local ok, err = pcall(function()
        writefile(path, HttpService:JSONEncode(Kumpulkan()))
    end)

    if not ok then
        return false, "Gagal tulis: " .. tostring(err)
    end

    State.SelectedConfig = name
    RefreshConfigList()

    return true, "Config \"" .. name .. "\" dibuat."
end

--[[
    Overwrite config terpilih dengan setting UI saat ini.
    Nama config tidak diubah, jadi autoload tetap ke file yang sama.
]]
local function ConfigOverwriteSelected()
    local name = RequireSelected("Overwrite")
    if not name then
        return false, "Gagal overwrite."
    end

    local ok, err = pcall(function()
        writefile(ConfigPath(name), HttpService:JSONEncode(Kumpulkan()))
    end)

    if not ok then
        return false, "Gagal tulis: " .. tostring(err)
    end

    return true, "Config \"" .. name .. "\" di-overwrite dengan setting sekarang."
end

--[[
    Load config terpilih lalu terapkan ke UI.
]]
local function ConfigLoadSelected()
    local name = RequireSelected("Load")
    if not name then
        return false, "Gagal load."
    end

    local ok, raw = pcall(readfile, ConfigPath(name))

    if not ok or type(raw) ~= "string" or raw == "" then
        return false, "Gagal baca config."
    end

    local decoded
    local decodeOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)

    if not decodeOk or type(decoded) ~= "table" then
        return false, "JSON config rusak."
    end

    local applied, info = Terapkan(decoded)

    if not applied then
        return false, info
    end

    return true, "Config \"" .. name .. "\" dimuat."
end

--[[
    Hapus config terpilih.
]]
local function ConfigDeleteSelected()
    local name = RequireSelected("Delete")
    if not name then
        return false, "Gagal hapus."
    end

    local ok = pcall(delfile, ConfigPath(name))

    if not ok then
        return false, "Gagal hapus file."
    end

    --[[
        Kalau config yang dihapus adalah autoload aktif,
        pointer autoload ikut dibersihkan.
    ]]
    local catatan = ""

    if State.AutoloadConfig == name then
        State.AutoloadConfig = nil

        if HasFileAPI() and isfile(AutoloadPath()) then
            pcall(delfile, AutoloadPath())
        end

        catatan = " (autoload ikut dilepas)"
    end

    State.SelectedConfig = nil
    RefreshConfigList()

    return true, "Config \"" .. name .. "\" dihapus." .. catatan
end

--[[
    Reset config terpilih ke default.
    File tetap ada, isinya ditulis ulang dengan nilai default.
]]
local function ConfigResetSelected()
    local name = RequireSelected("Reset")
    if not name then
        return false, "Gagal reset."
    end

    -- Kembalikan UI + state ke default
    for i = 1, 2 do
        Controls.WebhookUrl[i]:Set("")
        Controls.CaptureAll[i]:Set(false)
        Controls.OwnBooth[i]:Set(false)
    end

    Controls.GoldSuffix:Set("gold")
    Controls.DecimalSeparator:Set(".")

    if Controls.ShowCurrentGold then
        Controls.ShowCurrentGold:Set(false)
    end

    if Controls.ShowCoinImage then
        Controls.ShowCoinImage:Set(false)
    end

    -- Tulis ulang file dengan nilai default
    local ok, err = pcall(function()
        writefile(ConfigPath(name), HttpService:JSONEncode(Kumpulkan()))
    end)

    if not ok then
        return false, "Reset UI ok, tapi gagal tulis: " .. tostring(err)
    end

    return true, "Config \"" .. name .. "\" di-reset ke default."
end

--==================================================
-- AUTOLOAD CONFIG
--==================================================

--[[
    Set autoload ke config terpilih.
    File autoload cuma berisi nama config.
]]
local function SetAutoloadSelected()
    local name = RequireSelected("Set Autoload")
    if not name then
        return false, "Gagal set autoload."
    end

    if not EnsureDir(State.AutoloadDir) then
        return false, "Gagal membuat folder: " .. State.AutoloadDir
    end

    local ok, err = pcall(function()
        writefile(AutoloadPath(), name)
    end)

    if not ok then
        return false, "Gagal tulis autoload: " .. tostring(err)
    end

    State.AutoloadConfig = name

    return true, "Autoload diset ke config \"" .. name .. "\"."
end

--[[
    Remove autoload.
]]
local function RemoveAutoload()
    if not HasFileAPI() then
        return false, "Executor tidak punya file API."
    end

    if not isfile(AutoloadPath()) then
        State.AutoloadConfig = nil
        return true, "Tidak ada autoload."
    end

    local ok = pcall(delfile, AutoloadPath())

    if not ok then
        return false, "Gagal hapus autoload."
    end

    local sebelumnya = State.AutoloadConfig
    State.AutoloadConfig = nil

    return true, "Autoload dilepas" .. (sebelumnya and (" dari \"" .. sebelumnya .. "\".") or ".")
end

--[[
    Baca config mana yang di-autoload.
]]
local function ReadAutoload()
    if not HasFileAPI() then
        return nil
    end

    if not isfile(AutoloadPath()) then
        return nil
    end

    local ok, raw = pcall(readfile, AutoloadPath())

    if not ok or type(raw) ~= "string" then
        return nil
    end

    local name = SanitizeName(raw)

    if not name or not isfile(ConfigPath(name)) then
        return nil
    end

    return name
end

--[[
    Auto-load config yang di-autoload.
    Dipanggil sekali saat script start.
]]
local function AutoLoadConfig()
    if not HasFileAPI() then
        return false
    end

    local name = ReadAutoload()

    if not name then
        return false
    end

    State.SelectedConfig = name
    RefreshConfigList()

    local ok, raw = pcall(readfile, ConfigPath(name))

    if not ok or type(raw) ~= "string" or raw == "" then
        return false, "Gagal baca autoload config."
    end

    local decoded
    local decodeOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)

    if not decodeOk or type(decoded) ~= "table" then
        return false, "JSON config rusak."
    end

    local applied, info = Terapkan(decoded)

    if not applied then
        return false, info
    end

    State.AutoloadConfig = name

    return true, "Config \"" .. name .. "\" dimuat otomatis."
end

--==================================================
-- 05_message.luau
--==================================================
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

--==================================================
-- 06_ui.luau
--==================================================
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

--==================================================
-- 07_event.luau
--==================================================
--[[
    07_event.luau
    Handler event Shop_PurchasedFromShop.
]]

local PurchaseEvent = ReplicatedStorage:WaitForChild(State.RemotePath[1])
    :WaitForChild(State.RemotePath[2])

--[[
    Arg minimal yang dibutuhkan:
    buyer, seller, item, quantity, price, remaining
]]
local MIN_ARGS = 6

local function HitungTotal(quantity, price)
    local q = tonumber(quantity)
    local p = tonumber(price)

    if not q or not p then
        return nil
    end

    return q * p
end

--[[
    True kalau ada minimal satu webhook yang aktif.
]]
local function AdaWebhookAktif()
    return WebhookMode(1) ~= "Off" or WebhookMode(2) ~= "Off"
end

PurchaseEvent.OnClientEvent:Connect(function(...)
    if not AdaWebhookAktif() then
        return
    end

    local args = { ... }

    if #args < MIN_ARGS then
        return
    end

    local buyerName = ResolveName(args[1])
    local sellerName = ResolveName(args[2])

    if not buyerName or not sellerName then
        return
    end

    local itemName = ResolveItemName(args[3])

    local isOwnBooth = (sellerName == LocalName)

    local data = {
        -- Buyer selalu dari argument
        Buyer = buyerName,

        --[[
            Kalau ini booth sendiri, seller adalah kita.
            Pakai LocalName langsung supaya field Seller menampilkan
            nama asli, bukan placeholder "LocalPlayer" atau
            nama yang formatnya beda dari args.
        ]]
        Seller = isOwnBooth and LocalName or sellerName,

        Item = itemName,
        Quantity = args[4],
        UnitPrice = args[5],
        Total = HitungTotal(args[4], args[5]),
        Remaining = args[6],

        --[[
            Sisa gold lu, hanya kalau toggle-nya nyala.
            Dibaca di sini (bukan di BangunPesan) supaya
            nil kalau label coin belum ketemu = baris disembunyikan.
        ]]
        CurrentGold = State.ShowCurrentGold and ReadCurrentGold() or nil,

        --[[
            Icon gold coin. Roblox nggak bisa upload gambar lokal,
            jadi ResolveCoinImageUrl bikin URL publik dari asset ID.
        ]]
        CoinImageUrl = State.ShowCoinImage and ResolveCoinImageUrl() or nil
    }

    local pesan, embed = BangunPesan(data)

    print(pesan)

    --[[
        Filter OwnBooth membandingkan data.Seller dengan LocalName,
        jadi cukup kirim satu sumber kebenaran.
    ]]
    local results = KirimPesan(pesan, embed, data.Seller)

    if results[1] or results[2] then
        local separator = State.DecimalSeparator
        local qty = FormatAngka(data.Quantity, separator)
        local total = FormatGold(data.Total, State.GoldSuffix, separator)

        Notify(
            "Purchase Detected",
            string.format("%s beli %s x%s - %s", buyerName, itemName, qty, total),
            5
        )
    end
end)

--==================================================
-- 08_footer.luau
--==================================================
--[[
    08_footer.luau
    Tab Misc (Display + Destroy) dan tab Settings (Config Manager + Autoload).
]]

--==================================================
-- MISC
--==================================================

local MiscTab = Window:CreateTab("Misc")

MiscTab:CreateSection("Display")

Controls.GoldSuffix = MiscTab:CreateInput({
    Name = "Gold Suffix",
    PlaceholderText = "gold",
    RemoveTextAfterFocusLost = false,
    Flag = "GoldSuffix",

    Callback = function(Value)
        local bersih = Trim(Value)
        State.GoldSuffix = bersih == "" and "gold" or bersih
    end
})

Controls.DecimalSeparator = MiscTab:CreateInput({
    Name = "Decimal Separator",
    PlaceholderText = ".",
    RemoveTextAfterFocusLost = false,
    Flag = "DecimalSeparator",

    Callback = function(Value)
        local bersih = Trim(Value)
        State.DecimalSeparator = bersih == "" and "." or bersih
    end
})

MiscTab:CreateSection("Misc")

MiscTab:CreateButton({
    Name = "Destroy Script",
    Callback = function()
        Rayfield:Destroy()
    end
})

--==================================================
-- SETTINGS
--==================================================

local SettingsTab = Window:CreateTab("Settings")

SettingsTab:CreateSection("UI Settings")

Controls.ToggleUI = SettingsTab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightShift",
    HoldToInteract = false,
    Flag = "ToggleUI",

    Callback = function()
        Rayfield:SetVisibility(not Rayfield:IsVisible())
    end
})

--==================================================
-- CONFIG
--==================================================

-- CONFIG
--==================================================

SettingsTab:CreateSection("Config")

SettingsTab:CreateLabel("Nama config: huruf saja (A-Z).", nil, nil, true)

--[[
    Filter input: hanya huruf yang boleh masuk.
    Set ulang hanya kalau ada karakter non-huruf,
    jadi tidak memicu callback berulang.
]]
local sedangFilter = false

Controls.ConfigNameInput = SettingsTab:CreateInput({
    Name = "Config Name",
    PlaceholderText = "Config",
    RemoveTextAfterFocusLost = false,
    Flag = "ConfigName",

    Callback = function(Value)
        if sedangFilter then
            return
        end

        local bersih = tostring(Value):gsub("[^%a]", "")

        if bersih ~= Value and Controls.ConfigNameInput then
            sedangFilter = true
            Controls.ConfigNameInput:Set(bersih)
            sedangFilter = false
        end

        State.ConfigNameInput = bersih
    end
})

--[[
    Label autoload = sumber kebenaran tunggal di UI.
    Dipanggil ulang tiap autoload berubah.
]]
local function RefreshAutoloadLabel()
    local text = State.AutoloadConfig and ("Autoload: " .. State.AutoloadConfig) or "Autoload: (tidak ada)"

    if Controls.AutoloadLabel then
        Controls.AutoloadLabel:Set(text)
    end

    return text
end

local function ReportConfig(Title, ok, info)
    Notify(Title, ok and info or ("Gagal: " .. tostring(info)), 5)
end

SettingsTab:CreateButton({
    Name = "Create Config",
    Callback = function()
        local ok, info = ConfigCreate()
        ReportConfig("Create Config", ok, info)
    end
})

--==================================================
-- CONFIG LIST
--==================================================

SettingsTab:CreateSection("Config List")

Controls.ConfigDropdown = SettingsTab:CreateDropdown({
    Name = "Selected Config",
    Options = { PICK_CONFIG },
    CurrentOption = PICK_CONFIG,
    Flag = "SelectedConfig",

    Callback = function(Option)
        if Option == NO_CONFIG or Option == PICK_CONFIG then
            State.SelectedConfig = nil
            return
        end

        State.SelectedConfig = Option
    end
})

SettingsTab:CreateButton({
    Name = "Refresh List",
    Callback = function()
        RefreshConfigList()

        Notify(
            "Config List",
            #State.ConfigList > 0
                and #State.ConfigList .. " config ditemukan."
                or "Belum ada config.",
            4
        )
    end
})

SettingsTab:CreateButton({
    Name = "Load Config",
    Callback = function()
        local ok, info = ConfigLoadSelected()
        ReportConfig("Load Config", ok, info)
    end
})

SettingsTab:CreateButton({
    Name = "Overwrite Config",
    Callback = function()
        local ok, info = ConfigOverwriteSelected()
        ReportConfig("Overwrite Config", ok, info)
    end
})

SettingsTab:CreateButton({
    Name = "Reset Config",
    Callback = function()
        local ok, info = ConfigResetSelected()
        ReportConfig("Reset Config", ok, info)
    end
})

SettingsTab:CreateButton({
    Name = "Delete Config",
    Callback = function()
        local ok, info = ConfigDeleteSelected()

        --[[
            Kalau config yang dihapus adalah autoload aktif,
            pointer ikut dilepas oleh ConfigDeleteSelected.
        ]]
        if ok then
            RefreshAutoloadLabel()
        end

        ReportConfig("Delete Config", ok, info)
    end
})

--==================================================
-- AUTOLOAD CONFIG
--==================================================

SettingsTab:CreateSection("Autoload Config")

SettingsTab:CreateLabel("Otomatis load config yang dipilih tiap script dijalankan.", nil, nil, true)

SettingsTab:CreateButton({
    Name = "Set Autoload Config",
    Callback = function()
        local ok, info = SetAutoloadSelected()

        if ok then
            RefreshAutoloadLabel()
        end

        ReportConfig("Set Autoload", ok, info)
    end
})

SettingsTab:CreateButton({
    Name = "Remove Autoload Config",
    Callback = function()
        local ok, info = RemoveAutoload()

        if ok then
            RefreshAutoloadLabel()
        end

        ReportConfig("Remove Autoload", ok, info)
    end
})

Controls.AutoloadLabel = SettingsTab:CreateLabel("Autoload: (tidak ada)", nil, nil, true)

--==================================================
-- AUTO LOAD + REFRESH AWAL
--==================================================

--[[
    Config Rayfield dimatikan, jadi ini satu-satunya pemicu load.
    Ditunda satu frame supaya semua UI value object sudah
    terpasang di Controls sebelum config diterapkan.
]]
task.defer(function()
    if not HasFileAPI() then
        return
    end

    -- Isi dropdown dengan daftar config yang sudah ada
    RefreshConfigList()

    --[[
        Auto-load punya prioritas: kalau ada autoload pointer,
        config itu yang dipakai dan langsung jadi Selected Config.
        AutoLoadConfig sudah refresh dropdownnya sendiri.
    ]]
    local ok, info = AutoLoadConfig()

    RefreshAutoloadLabel()

    Notify("Config", ok and info or ("Auto load: " .. tostring(info)), 5)
end)


