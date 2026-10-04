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