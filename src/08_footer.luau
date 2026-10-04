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
