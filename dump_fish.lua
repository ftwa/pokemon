-- ==============================================================================
-- POKÉDEX SCOREBOARD — UNIVERSAL FISH IT DUMPER (TERMASUK PULAU BARU!)
-- Memindai SEMUA ikan (Legend / Mythic / Secret / Forgotten) dari game
-- lalu mengirim otomatis ke PokedexScoreboard.exe (127.0.0.1:18420)
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
        Title = "🐟 Pokédex Fish Dumper",
        Text = "Memindai semua ikan & pulau baru dari game...",
        Duration = 3
    })
end)

print("=============================================================")
print("🐟 POKÉDEX UNIVERSAL FISH DUMPER (ALL ISLANDS)")
print("=============================================================")

local dumped = {}

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

local function formatOdds(raw)
    if type(raw) == "table" then
        raw = raw.Chance or raw.Odds or raw.Probability or raw.Value
    end
    if type(raw) == "number" then
        if raw > 0 and raw < 1 then
            local inv = math.floor((1 / raw) + 0.5)
            return "1 in " .. tostring(inv)
        elseif raw >= 1 then
            return "1 in " .. tostring(math.floor(raw + 0.5))
        end
        return ""
    end
    if type(raw) == "string" and #raw > 0 and not raw:find("table:") then
        return raw
    end
    return ""
end

local function formatLocation(raw)
    if type(raw) == "string" and #raw > 0 and not raw:find("table:") then
        return raw
    end
    return ""
end

local function addFish(name, tierRaw, iconRaw, oddsRaw, locRaw)
    if type(name) ~= "string" or #name < 2 or #name > 60 then return end
    local tier = normalizeTier(tierRaw)
    if not tier then return end
    local assetId = extractAssetId(iconRaw)
    if not assetId then return end

    local key = string.lower(name):match("^%s*(.-)%s*$")
    if not key or #key < 2 then return end

    if not dumped[key] then
        dumped[key] = {
            name = name,
            tier = tier,
            assetId = assetId,
            odds = formatOdds(oddsRaw),
            location = formatLocation(locRaw)
        }
    end
end

local function inspectTable(tbl, depth)
    if type(tbl) ~= "table" or depth > 3 then return end
    local name = tbl.Name or tbl.name or tbl.FishName or tbl.ItemName or tbl.Title
    local icon = tbl.Icon or tbl.icon or tbl.Image or tbl.image or tbl.Texture or tbl.AssetId or tbl.Thumbnail
    local tier = tbl.Tier or tbl.tier or tbl.Rarity or tbl.rarity
    local odds = tbl.Odds or tbl.Chance or tbl.Probability or tbl.chance
    local loc  = tbl.Location or tbl.Island or tbl.Zone or tbl.Area or tbl.location

    if name and icon and tier then
        local itemType = string.lower(tostring(tbl.Type or tbl.Category or "fish"))
        if itemType == "" or itemType:find("fish") or itemType:find("item") or itemType:find("catch") or not tbl.Type then
            addFish(tostring(name), tier, icon, odds, loc)
        end
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if type(k) == "string" and not (v.Name or v.name) then
                local subIcon = v.Icon or v.icon or v.Image or v.image or v.Texture
                local subTier = v.Tier or v.tier or v.Rarity or v.rarity
                if subIcon and subTier then
                    addFish(k, subTier, subIcon, v.Odds or v.Chance, v.Location or v.Island)
                end
            end
            inspectTable(v, depth + 1)
        end
    end
end

-- 1. Pindai ModuleScripts di ReplicatedStorage
pcall(function()
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("ModuleScript") then
            local n = string.lower(inst.Name)
            if n:find("fish") or n:find("item") or n:find("index") or n:find("catalog") or n:find("data") or n:find("tier") or n:find("island") then
                pcall(function()
                    local mod = require(inst)
                    if type(mod) == "table" then
                        inspectTable(mod, 0)
                    end
                end)
            end
        end
    end
end)

-- 2. Pindai memori GC untuk tabel ikan aktif (menangkap pulau terbaru!)
local getgcFunc = getgc or (debug and debug.getgc)
if getgcFunc then
    pcall(function()
        for _, obj in ipairs(getgcFunc(true)) do
            if type(obj) == "table" then
                local name = obj.Name or obj.name or obj.FishName
                local icon = obj.Icon or obj.icon or obj.Image or obj.image
                local tier = obj.Tier or obj.tier or obj.Rarity or obj.rarity
                if name and icon and tier then
                    addFish(tostring(name), tier, icon, obj.Odds or obj.Chance, obj.Location or obj.Island)
                end
            end
        end
    end)
end

local list = {}
for _, v in pairs(dumped) do
    table.insert(list, v)
end
print(string.format("🐟 Total ikan turnamen ditemukan: %d ekor", #list))

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
                    Title = "✅ Dump Ikan Sukses!",
                    Text = string.format("%d ikan dikirim ke PokedexScoreboard.exe (mengunduh gambar ikan baru...)", #list),
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
