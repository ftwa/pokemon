-- ==============================================================================
-- POKÉDEX SCOREBOARD — UNIVERSAL FISH IT DUMPER v2 (PULAU & ODDS ASLI!)
-- Memindai SEMUA ikan (Legend / Mythic / Secret / Forgotten) + NAMA PULAU + ODDS
-- langsung dari ReplicatedStorage & Memori Game, lalu kirim ke 127.0.0.1:18420
-- ==============================================================================
local cloneref = cloneref or function(o) return o end
local HttpService = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (getgenv and getgenv().request)
    or (getgenv and getgenv().http_request)

local IMPORT_URL = "http://127.0.0.1:18420/api/import-fish-dump"

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🐟 Pokédex Fish Dumper v2",
        Text = "Memindai semua ikan, nama pulau & odds dari game...",
        Duration = 3
    })
end)

print("=============================================================")
print("🐟 POKÉDEX UNIVERSAL FISH DUMPER v2 (ALL ISLANDS + ODDS)")
print("=============================================================")

local dumped = {}            -- [lowerName] = { name, tier, assetId, odds, location, id }
local nameById = {}          -- [tostring(id)] = lowerName
local islandByName = {}      -- [lowerName] = islandName
local islandById = {}        -- [tostring(id)] = islandName
local oddsByName = {}        -- [lowerName] = formattedOdds
local oddsById = {}          -- [tostring(id)] = formattedOdds
local visitedTbls = {}

local GENERIC_NAMES = {
    items = true, item = true, fish = true, fishes = true, data = true,
    modules = true, module = true, shared = true, assets = true, asset = true,
    replicatedstorage = true, config = true, configs = true, database = true,
    db = true, index = true, bestiary = true, catalog = true, registry = true,
    areas = true, area = true, zones = true, zone = true, locations = true,
    location = true, islands = true, island = true, regions = true, region = true,
    fishingareas = true, fishingzones = true, pools = true, pool = true,
    loot = true, lootpool = true, drops = true, chances = true, weights = true,
    probability = true, tiers = true, rarities = true, client = true, server = true,
    util = true, utils = true, packages = true, lib = true, rods = true, baits = true,
    variants = true, mutations = true, skins = true, gears = true, boats = true,
    default = true, all = true, list = true, table = true, info = true, meta = true,
    ["new island"] = true, ["unknown"] = true, ["none"] = true, ["nil"] = true
}

local function isValidIslandName(raw)
    if type(raw) ~= "string" then return false end
    local s = raw:match("^%s*(.-)%s*$")
    if #s < 3 or #s > 48 then return false end
    if s:find("table:") or s:find("function:") or s:find("rbxassetid") or s:find("^%d+$") then return false end
    if GENERIC_NAMES[string.lower(s)] then return false end
    return true
end

local function normalizeTier(raw)
    if type(raw) == "number" then
        if raw >= 8 then return "forgotten"
        elseif raw == 7 then return "secret"
        elseif raw == 6 then return "mitos"
        elseif raw == 5 then return "legend"
        else return nil end
    end
    local s = string.lower(tostring(raw or ""))
    if s:find("forgotten") then return "forgotten"
    elseif s:find("secret") then return "secret"
    elseif s:find("mythic") or s:find("mitos") then return "mitos"
    elseif s:find("legend") then return "legend"
    end
    return nil
end

local function extractAssetId(raw)
    if type(raw) ~= "string" and type(raw) ~= "number" then return nil end
    local id = string.match(tostring(raw), "%d+")
    if id and #id >= 5 then return id end
    return nil
end

local function formatNumberDot(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    if out:sub(1, 1) == "." then out = out:sub(2) end
    return out
end

local function formatOdds(raw)
    if type(raw) == "table" then
        raw = raw.Chance or raw.chance or raw.Odds or raw.odds or raw.Probability or raw.Value or raw.Rate
    end
    if type(raw) == "number" then
        if raw > 0 and raw < 1 then
            local inv = math.floor((1 / raw) + 0.5)
            if inv >= 2 then
                return "1 in " .. formatNumberDot(inv)
            end
        elseif raw >= 100 then
            return "1 in " .. formatNumberDot(raw)
        end
        return ""
    end
    if type(raw) == "string" and #raw > 0 and not raw:find("table:") and raw ~= "-" then
        return raw:match("^%s*(.-)%s*$")
    end
    return ""
end

local function formatLocation(raw)
    if type(raw) == "table" then
        raw = raw.Name or raw.DisplayName or raw.Title or raw.Island or raw.Area or raw.Zone or raw[1]
    end
    if isValidIslandName(raw) then
        return raw:match("^%s*(.-)%s*$")
    end
    return ""
end

local function registerFish(name, tierRaw, iconRaw, oddsRaw, locRaw, idRaw)
    if type(name) ~= "string" or #name < 2 or #name > 60 then return end
    local tier = normalizeTier(tierRaw)
    if not tier then return end
    local assetId = extractAssetId(iconRaw)
    if not assetId then return end

    local key = string.lower(name):match("^%s*(.-)%s*$")
    if not key or #key < 2 then return end

    local cleanOdds = formatOdds(oddsRaw)
    local cleanLoc = formatLocation(locRaw)
    local idStr = (type(idRaw) == "number" or type(idRaw) == "string") and tostring(idRaw) or nil

    if idStr and #idStr > 0 then
        nameById[idStr] = key
    end

    local cur = dumped[key]
    if not cur then
        dumped[key] = {
            name = name,
            tier = tier,
            assetId = assetId,
            odds = cleanOdds,
            location = cleanLoc,
            _id = idStr
        }
    else
        if cur.odds == "" and cleanOdds ~= "" then cur.odds = cleanOdds end
        if cur.location == "" and cleanLoc ~= "" then cur.location = cleanLoc end
        if not cur._id and idStr then cur._id = idStr end
    end
end

local function recordIslandLink(islandName, fishRef, maybeChance)
    if not isValidIslandName(islandName) then return end
    local cleanIsland = islandName:match("^%s*(.-)%s*$")
    local cleanOdds = formatOdds(maybeChance)

    if type(fishRef) == "number" then
        local sid = tostring(fishRef)
        if not islandById[sid] then islandById[sid] = cleanIsland end
        if cleanOdds ~= "" and not oddsById[sid] then oddsById[sid] = cleanOdds end
    elseif type(fishRef) == "string" then
        local k = string.lower(fishRef):match("^%s*(.-)%s*$")
        if #k >= 2 then
            if k:match("^%d+$") then
                if not islandById[k] then islandById[k] = cleanIsland end
                if cleanOdds ~= "" and not oddsById[k] then oddsById[k] = cleanOdds end
            else
                if not islandByName[k] then islandByName[k] = cleanIsland end
                if cleanOdds ~= "" and not oddsByName[k] then oddsByName[k] = cleanOdds end
            end
        end
    end
end

local function isExcludedItemType(rawType)
    local t = string.lower(tostring(rawType or ""))
    if t == "" then return false end
    local bad = {
        "rod", "bait", "boat", "skin", "bobber", "charm", "lantern",
        "totem", "crate", "potion", "boost", "title", "emote", "pet",
        "cosmetic", "gear", "tool", "weapon", "sword", "katana", "guitar",
        "quest", "currency", "pass", "gamepass", "bundle", "egg", "chest"
    }
    for _, b in ipairs(bad) do
        if t:find(b, 1, true) then return true end
    end
    return false
end

local function inspectFishObject(tbl, parentLoc, depth)
    if type(tbl) ~= "table" or depth > 4 then return end
    if visitedTbls[tbl] then return end
    visitedTbls[tbl] = true

    -- Kasus Fish It: { Data = { Name, Tier, Icon, Id, Type }, Probability = { Chance = ... } }
    local dataSub = (type(tbl.Data) == "table") and tbl.Data or tbl
    local name = dataSub.Name or dataSub.name or dataSub.FishName or dataSub.ItemName or dataSub.Title
    local icon = dataSub.Icon or dataSub.icon or dataSub.Image or dataSub.image or dataSub.Texture or dataSub.AssetId or dataSub.Thumbnail or tbl.Icon or tbl.Image
    local tier = dataSub.Tier or dataSub.tier or dataSub.Rarity or dataSub.rarity or tbl.Tier or tbl.Rarity
    local idVal = dataSub.Id or dataSub.ID or dataSub.id or tbl.Id or tbl.ID or tbl.ItemId
    local odds = tbl.Probability or tbl.Odds or tbl.Chance or tbl.chance or dataSub.Probability or dataSub.Odds or dataSub.Chance
    local loc  = tbl.Location or tbl.Island or tbl.Zone or tbl.Area or tbl.Region or tbl.Biome or tbl.location
        or dataSub.Location or dataSub.Island or dataSub.Zone or dataSub.Area or dataSub.Region or dataSub.Biome
        or parentLoc

    if name and icon and tier then
        local rawType = dataSub.Type or tbl.Type or dataSub.Category or tbl.Category or ""
        local itemType = string.lower(tostring(rawType))
        if not isExcludedItemType(rawType) and (itemType == "" or itemType == "fish" or itemType:find("fish") or itemType == "item" or itemType == "catch") then
            registerFish(tostring(name), tier, icon, odds, loc, idVal)
        end
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" and k ~= "Data" and k ~= "Probability" and k ~= "Weight" then
            local nextParentLoc = parentLoc
            if type(k) == "string" and isValidIslandName(k) then
                -- Jika v adalah container daftar ikan milik sebuah pulau, teruskan nama pulaunya
                if not (v.Icon or v.icon or (type(v.Data) == "table" and v.Data.Icon)) then
                    nextParentLoc = k
                end
            end
            if type(k) == "string" and not (v.Name or v.name or (type(v.Data) == "table" and v.Data.Name)) then
                local subData = (type(v.Data) == "table") and v.Data or v
                local subIcon = subData.Icon or subData.icon or subData.Image or subData.image or subData.Texture
                local subTier = subData.Tier or subData.tier or subData.Rarity or subData.rarity
                if subIcon and subTier then
                    registerFish(k, subTier, subIcon, v.Probability or v.Odds or v.Chance, v.Location or v.Island or v.Zone or v.Area or parentLoc, subData.Id or v.Id)
                end
            end
            inspectFishObject(v, nextParentLoc, depth + 1)
        end
    end
end

local function extractPoolEntries(islandName, poolTbl, depth)
    if type(poolTbl) ~= "table" or depth > 3 then return end
    for k, v in pairs(poolTbl) do
        if type(v) == "number" then
            if type(k) == "string" then
                -- { ["Megalodon"] = 0.00000025 } atau { ["Megalodon"] = 50 }
                recordIslandLink(islandName, k, v)
            elseif type(k) == "number" then
                -- Array of Fish IDs: { 101, 102, 103 }
                recordIslandLink(islandName, v, nil)
            end
        elseif type(v) == "string" then
            -- Array of Fish Names: { "Megalodon", "Orca" }
            recordIslandLink(islandName, v, nil)
        elseif type(v) == "table" then
            local fName = v.Name or v.Fish or v.FishName or v.Item or v.ItemName or (type(v.Data) == "table" and v.Data.Name)
            local fId = v.Id or v.ID or v.ItemId or v.FishId or (type(v.Data) == "table" and v.Data.Id)
            local fChance = v.Chance or v.Odds or v.Probability or v.Weight or v.Rate
            if fName then recordIslandLink(islandName, fName, fChance) end
            if fId then recordIslandLink(islandName, fId, fChance) end
            if type(k) == "string" and not fName and not isValidIslandName(v.Name or "") then
                -- Key adalah nama ikan: { ["Megalodon"] = { Chance = ... } }
                recordIslandLink(islandName, k, fChance)
            end
            if not fName and not fId then
                extractPoolEntries(islandName, v, depth + 1)
            end
        end
    end
end

local function inspectAreaTable(tbl, fallbackIslandName, depth)
    if type(tbl) ~= "table" or depth > 4 then return end
    local areaName = tbl.DisplayName or tbl.AreaName or tbl.IslandName or tbl.ZoneName or tbl.Name or tbl.Title or fallbackIslandName
    local validArea = isValidIslandName(areaName) and areaName or (isValidIslandName(fallbackIslandName) and fallbackIslandName or nil)

    local poolKeys = {
        "Fish", "Fishes", "FishPool", "LootPool", "Pool", "Drops", "Items",
        "Catches", "Spawns", "Table", "FishList", "AvailableFish", "CatchPool",
        "TierPool", "Rarities", "Entries", "Bestiary", "Index", "Data"
    }
    if validArea then
        for _, pk in ipairs(poolKeys) do
            local sub = tbl[pk]
            if type(sub) == "table" then
                extractPoolEntries(validArea, sub, 0)
            end
        end
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            local nextName = validArea
            if type(k) == "string" and isValidIslandName(k) then
                nextName = k
            end
            inspectAreaTable(v, nextName, depth + 1)
        end
    end
end

-- ==============================================================================
-- LANGKAH 1: Pindai ModuleScripts di ReplicatedStorage (Ikan + Area/Pulau)
-- ==============================================================================
pcall(function()
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local n = string.lower(inst.Name)
            local pName = inst.Parent and inst.Parent.Name or ""
            local pLower = string.lower(pName)
            local folderLoc = isValidIslandName(pName) and pName or ""

            local isFishMod = n:find("fish") or n:find("item") or n:find("index") or n:find("catalog") or n:find("data") or n:find("tier") or pLower:find("item") or pLower:find("fish")
            local isAreaMod = n:find("area") or n:find("zone") or n:find("island") or n:find("location") or n:find("region") or n:find("pool") or n:find("loot") or n:find("bestiary") or n:find("index") or n:find("map") or pLower:find("area") or pLower:find("zone") or pLower:find("island") or pLower:find("location")

            if isFishMod or isAreaMod then
                pcall(function()
                    local mod = require(inst)
                    if type(mod) == "table" then
                        if isFishMod then
                            inspectFishObject(mod, folderLoc, 0)
                        end
                        if isAreaMod then
                            local modIsland = isValidIslandName(inst.Name) and inst.Name or folderLoc
                            inspectAreaTable(mod, modIsland, 0)
                        end
                    end
                end)
            end
        end
    end
end)

-- ==============================================================================
-- LANGKAH 2: Pindai Memori GC (Ikan + Tabel Area/Pulau Aktif)
-- ==============================================================================
local getgcFunc = getgc or (debug and debug.getgc)
if getgcFunc then
    pcall(function()
        for _, obj in ipairs(getgcFunc(true)) do
            if type(obj) == "table" then
                -- Cek apakah tabel ikan (langsung atau lewat .Data)
                local dataSub = (type(obj.Data) == "table") and obj.Data or obj
                local name = dataSub.Name or dataSub.name or dataSub.FishName
                local icon = dataSub.Icon or dataSub.icon or dataSub.Image or dataSub.image or obj.Icon
                local tier = dataSub.Tier or dataSub.tier or dataSub.Rarity or dataSub.rarity or obj.Tier
                local rawType = dataSub.Type or obj.Type or dataSub.Category or obj.Category or ""
                if name and icon and tier and not isExcludedItemType(rawType) then
                    local idVal = dataSub.Id or dataSub.ID or obj.Id or obj.ID
                    local odds = obj.Probability or obj.Odds or obj.Chance or dataSub.Probability or dataSub.Odds or dataSub.Chance
                    local loc = obj.Location or obj.Island or obj.Zone or obj.Area or obj.Region or dataSub.Location or dataSub.Island or dataSub.Zone or dataSub.Area
                    registerFish(tostring(name), tier, icon, odds, loc, idVal)
                end

                -- Cek apakah tabel Area / Island / Zone
                local aName = obj.DisplayName or obj.AreaName or obj.IslandName or obj.ZoneName or obj.Name
                local aPool = obj.Fish or obj.Fishes or obj.FishPool or obj.LootPool or obj.Pool or obj.AvailableFish or obj.CatchPool
                if type(aPool) == "table" and isValidIslandName(aName) then
                    extractPoolEntries(aName, aPool, 0)
                end
            end
        end
    end)
end

-- ==============================================================================
-- LANGKAH 3: Gabungkan Nama Pulau & Odds Asli ke Setiap Ikan
-- ==============================================================================
local list = {}
local withIsland = 0
local withOdds = 0
local uniqueIslands = {}

for key, v in pairs(dumped) do
    local loc = v.location
    if loc == "" then
        loc = islandByName[key] or (v._id and islandById[v._id]) or ""
    end
    local odds = v.odds
    if odds == "" then
        odds = oddsByName[key] or (v._id and oddsById[v._id]) or ""
    end

    if loc ~= "" then
        withIsland = withIsland + 1
        uniqueIslands[loc] = true
    end
    if odds ~= "" then
        withOdds = withOdds + 1
    end

    table.insert(list, {
        name = v.name,
        tier = v.tier,
        assetId = v.assetId,
        odds = odds,
        location = loc
    })
end

local islandCount = 0
for _ in pairs(uniqueIslands) do islandCount = islandCount + 1 end

print(string.format("🐟 Total ikan turnamen ditemukan: %d ekor", #list))
print(string.format("🏝️ Terpetakan ke %d pulau (%d ikan punya nama pulau, %d punya odds)", islandCount, withIsland, withOdds))

-- Cetak 10 sampel pertama di console agar mudah dicek
for i = 1, math.min(10, #list) do
    local f = list[i]
    print(string.format("   [%d] %s (%s) | Pulau: %s | Odds: %s", i, f.name, string.upper(f.tier), (f.location ~= "" and f.location or "-"), (f.odds ~= "" and f.odds or "-")))
end

if #list == 0 then
    warn("⚠️ Tidak menemukan tabel ikan. Coba buka menu Index / Fish Book di dalam game lalu jalankan ulang script ini!")
    return
end

if httpRequest then
    local ok, err = pcall(function()
        local res = httpRequest({
            Url = IMPORT_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ fish = list })
        })
        if res and res.StatusCode == 200 then
            print("✅ [POKÉDEX IMPORT] Berhasil dikirim ke PokedexScoreboard.exe! Respon: " .. tostring(res.Body))
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "✅ Dump Ikan v2 Sukses!",
                    Text = string.format("%d ikan (%d pulau terdeteksi) dikirim ke PokedexScoreboard!", #list, islandCount),
                    Duration = 5
                })
            end)
        else
            warn("⚠️ Gagal mengirim ke PokedexScoreboard.exe (status: " .. tostring(res and res.StatusCode or "offline") .. "). Pastikan aplikasi Desktop terbuka!")
        end
    end)
    if not ok then
        warn("⚠️ HTTP Error: " .. tostring(err))
    end
end
