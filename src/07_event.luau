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