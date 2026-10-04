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