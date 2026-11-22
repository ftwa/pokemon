-- ==============================================================================
-- POKÉDEX CATCH LOGGER v3 — PURE EVENT (TANPA CHAT) + TIER & MUTASI RAPI
-- Membaca tangkapan SEMUA player di seluruh server (Common -> Forgotten)
-- Menampilkan: [ROD/PET] | Player | TIER | Nama Ikan | Berat | Big/Shiny/Mutasi
-- ==============================================================================
local cloneref = cloneref or function(o) return o end
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local env = getgenv and getgenv()
if env and env._PokedexProbeStop then
    pcall(env._PokedexProbeStop)
end

local conns = {}
local active = true
local totalLogged = 0
local DURATION_SEC = 90

-- ==============================================================================
-- 1. PETA TIER & BATAS BERAT "BIG" DARI KATALOG IKAN GAME
-- ==============================================================================
local TIER_NAMES = {
    [1] = "COMMON",
    [2] = "UNCOMMON",
    [3] = "RARE",
    [4] = "EPIC",
    [5] = "LEGENDARY",
    [6] = "MYTHIC",
    [7] = "SECRET",
    [8] = "FORGOTTEN"
}

local FISH_INFO = {} -- [lowerName] = { tier = "EPIC", bigMin = 120 }

local function tierToLabel(raw)
    if type(raw) == "number" then
        return TIER_NAMES[raw] or (raw >= 8 and "FORGOTTEN" or "COMMON")
    end
    local s = string.upper(tostring(raw or ""))
    if s:find("FORGOTTEN") then return "FORGOTTEN"
    elseif s:find("SECRET") then return "SECRET"
    elseif s:find("MYTHIC") or s:find("MITOS") then return "MYTHIC"
    elseif s:find("LEGEND") then return "LEGENDARY"
    elseif s:find("EPIC") then return "EPIC"
    elseif s:find("RARE") then return "RARE"
    elseif s:find("UNCOMMON") then return "UNCOMMON"
    elseif s:find("COMMON") then return "COMMON"
    end
    return "UNKNOWN"
end

local function extractBigMin(weightTbl)
    if type(weightTbl) ~= "table" then return nil end
    local big = weightTbl.Big
    if typeof(big) == "NumberRange" then
        return big.Min
    elseif type(big) == "table" then
        return tonumber(big.Min or big[1])
    elseif type(big) == "number" then
        return big
    end
    return nil
end

local function loadFishCatalog()
    local count = 0
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    local roots = itemsFolder and { itemsFolder } or { ReplicatedStorage }

    local function indexEntry(tbl)
        if type(tbl) ~= "table" then return end
        local d = (type(tbl.Data) == "table") and tbl.Data or tbl
        if type(d.Name) == "string" and (d.Tier or tbl.Tier or d.Rarity or tbl.Rarity) then
            local k = string.lower(d.Name):match("^%s*(.-)%s*$")
            if k and #k >= 2 and not FISH_INFO[k] then
                FISH_INFO[k] = {
                    tier = tierToLabel(d.Tier or tbl.Tier or d.Rarity or tbl.Rarity),
                    bigMin = extractBigMin(tbl.Weight or d.Weight)
                }
                count = count + 1
            end
        end
    end

    pcall(function()
        for _, root in ipairs(roots) do
            for _, inst in ipairs(root:GetDescendants()) do
                if inst:IsA("ModuleScript") then
                    local ok, mod = pcall(require, inst)
                    if ok and type(mod) == "table" then
                        indexEntry(mod)
                        for _, v in pairs(mod) do
                            if type(v) == "table" then
                                indexEntry(v)
                            end
                        end
                    end
                end
            end
        end
    end)
    return count
end

local catalogCount = loadFishCatalog()

-- ==============================================================================
-- 2. FORMATTER LOG TANGKAPAN RAPI (TANPA CHAT & TANPA VARIANTSEED)
-- ==============================================================================
local function onStructuredCatch(plr, fishName, meta)
    if not active then return end
    totalLogged = totalLogged + 1

    local isPet = type(meta.Attributes) == "table" and tostring(meta.Attributes.Source or "") == "PetFishing"
    local srcTag = isPet and "[PET]" or "[ROD]"

    local weightNum = tonumber(meta.Weight) or 0
    local weightStr = string.format("%.2f kg", weightNum)

    local info = FISH_INFO[string.lower(fishName)]
    local tierStr = info and info.tier or "UNKNOWN"

    local isBig = (meta.Big == true) or (info and info.bigMin and weightNum >= info.bigMin) or false
    local isShiny = (meta.Shiny == true)

    local mutRaw = meta.VariantId or meta.Variant or meta.Mutation
    if (not mutRaw or tostring(mutRaw) == "" or tostring(mutRaw) == "None") and type(meta.Attributes) == "table" then
        mutRaw = meta.Attributes.VariantId or meta.Attributes.Variant or meta.Attributes.Mutation
    end
    local mutStr = (mutRaw and tostring(mutRaw) ~= "" and tostring(mutRaw) ~= "None") and tostring(mutRaw) or "-"

    local flags = {}
    if isBig then table.insert(flags, "BIG") end
    if isShiny then table.insert(flags, "SHINY") end
    local flagStr = #flags > 0 and table.concat(flags, "+") or "-"

    local disp = plr.DisplayName or plr.Name
    local userTag = (disp ~= plr.Name) and string.format("%s (@%s)", disp, plr.Name) or ("@" .. plr.Name)
    if #userTag > 24 then userTag = userTag:sub(1, 23) .. "." end

    local cleanFish = (#fishName > 22) and (fishName:sub(1, 21) .. ".") or fishName

    print(string.format(
        "%s #%03d | %-24s | %-9s | %-22s | %9s | %-9s | Mutasi: %s",
        srcTag, totalLogged, userTag, tierStr, cleanFish, weightStr, flagStr, mutStr
    ))
end

print("=====================================================================================================")
print(string.format("🎣 [CATCH LOGGER v3] Aktif %d detik (Tanpa Chat | Katalog: %d ikan dimuat)", DURATION_SEC, catalogCount))
print("   SUMBER #No | PLAYER                   | TIER      | NAMA IKAN              |     BERAT | BIG/SHINY | MUTASI")
print("-----------------------------------------------------------------------------------------------------")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🎣 Catch Logger v3",
        Text = string.format("Aktif %ds! Katalog %d ikan (Common–Forgotten) siap di F9.", DURATION_SEC, catalogCount),
        Duration = 4
    })
end)

-- Hubungkan hanya ke RemoteEvent yang mengirim pola tangkapan (Player, Vector3, FishName, {Weight})
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            local ok, c = pcall(function()
                return desc.OnClientEvent:Connect(function(a1, a2, a3, a4)
                    if not active then return end
                    if typeof(a1) == "Instance" and a1:IsA("Player")
                        and typeof(a2) == "Vector3"
                        and typeof(a3) == "string" and #a3 >= 2
                        and type(a4) == "table" and type(a4.Weight) == "number" then
                        onStructuredCatch(a1, a3, a4)
                    end
                end)
            end)
            if ok and c then
                table.insert(conns, c)
            end
        end
    end
end)

local function stopProbe()
    if not active then return end
    active = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
    print("=====================================================================================================")
    print("🛑 [CATCH LOGGER v3] Selesai! Total tercatat: " .. totalLogged .. " tangkapan.")
    print("=====================================================================================================")
end

if env then env._PokedexProbeStop = stopProbe end
task.delay(DURATION_SEC, stopProbe)
