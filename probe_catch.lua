-- ==============================================================================
-- POKÉDEX CATCH LOGGER v3.1 — CEK TABEL TIER ASLI & EVENT LEGEND+
-- ==============================================================================
local cloneref = cloneref or function(o) return o end
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local env = getgenv and getgenv()
if env and env._PokedexProbeStop then
    pcall(env._PokedexProbeStop)
end

local conns = {}
local active = true
local totalLogged = 0
local DURATION_SEC = 75

-- 1. Baca tabel TIER resmi langsung dari game (ReplicatedStorage)
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

pcall(function()
    for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
        if inst:IsA("ModuleScript") and string.lower(inst.Name):find("tier") then
            local ok, mod = pcall(require, inst)
            if ok and type(mod) == "table" then
                local found = {}
                for k, v in pairs(mod) do
                    if type(v) == "table" and (v.Name or v.Tier) then
                        local tid = tonumber(v.Tier or k)
                        if tid and v.Name then
                            TIER_NAMES[tid] = string.upper(tostring(v.Name))
                            table.insert(found, string.format("%d=%s", tid, TIER_NAMES[tid]))
                        end
                    elseif type(k) == "number" and type(v) == "string" then
                        TIER_NAMES[k] = string.upper(v)
                        table.insert(found, string.format("%d=%s", k, TIER_NAMES[k]))
                    end
                end
                if #found > 0 then
                    table.sort(found)
                    print("🏷️ [TIER GAME ASLI] (" .. inst.Name .. "): " .. table.concat(found, ", "))
                end
            end
        end
    end
end)

-- 2. Muat katalog ikan (simpan angka Tier asli juga!)
local FISH_INFO = {}

local function extractBigMin(weightTbl)
    if type(weightTbl) ~= "table" then return nil end
    local big = weightTbl.Big
    if typeof(big) == "NumberRange" then return big.Min
    elseif type(big) == "table" then return tonumber(big.Min or big[1])
    elseif type(big) == "number" then return big end
    return nil
end

local function loadFishCatalog()
    local count = 0
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    local roots = itemsFolder and { itemsFolder } or { ReplicatedStorage }

    local function indexEntry(tbl)
        if type(tbl) ~= "table" then return end
        local d = (type(tbl.Data) == "table") and tbl.Data or tbl
        if type(d.Name) == "string" and (d.Tier or tbl.Tier) then
            local k = string.lower(d.Name):match("^%s*(.-)%s*$")
            local rawTier = d.Tier or tbl.Tier
            if k and #k >= 2 and not FISH_INFO[k] then
                local tid = tonumber(rawTier)
                local tLabel = tid and (TIER_NAMES[tid] or ("T" .. tid)) or string.upper(tostring(rawTier))
                FISH_INFO[k] = {
                    tierNum = tid or 0,
                    tier = tLabel,
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
                            if type(v) == "table" then indexEntry(v) end
                        end
                    end
                end
            end
        end
    end)
    return count
end

local catalogCount = loadFishCatalog()

-- Cetak sampel tier ikan terkenal untuk verifikasi angka Tier
local samples = { "Synodontis", "Megalodon", "Starjam Tang", "Molten Parrotfish", "Dusty Horseshoe Crab", "Thunderhead Cuttlefish", "Orca" }
local sampleOut = {}
for _, sn in ipairs(samples) do
    local inf = FISH_INFO[string.lower(sn)]
    if inf then
        table.insert(sampleOut, string.format("%s=T%d(%s)", sn, inf.tierNum, inf.tier))
    else
        table.insert(sampleOut, sn .. "=NOT_FOUND")
    end
end
print("🔎 [SAMPEL KATALOG] " .. table.concat(sampleOut, " | "))

-- Simpan tangkapan terstruktur terakhir per player agar kita tahu apakah Legend+ ikut lewat RemoteEvent ini atau tidak!
local lastEventCatchByPlayer = {}

local function onStructuredCatch(remoteName, plr, fishName, meta)
    if not active then return end
    totalLogged = totalLogged + 1

    local isPet = type(meta.Attributes) == "table" and tostring(meta.Attributes.Source or "") == "PetFishing"
    local srcTag = isPet and "[PET]" or "[ROD]"

    local weightNum = tonumber(meta.Weight) or 0
    local info = FISH_INFO[string.lower(fishName)]
    local tierStr = info and string.format("T%d:%s", info.tierNum, info.tier) or "UNKNOWN"

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

    lastEventCatchByPlayer[string.lower(plr.Name)] = { fish = fishName, tier = tierStr, t = tick() }
    lastEventCatchByPlayer[string.lower(plr.DisplayName)] = { fish = fishName, tier = tierStr, t = tick() }

    local disp = plr.DisplayName or plr.Name
    local userTag = (disp ~= plr.Name) and string.format("%s (@%s)", disp, plr.Name) or ("@" .. plr.Name)
    if #userTag > 24 then userTag = userTag:sub(1, 23) .. "." end

    -- Cetak SEMUA Legend+ dengan bintang supaya langsung mencolok, dan tetap cetak sampel tier lain
    local star = (info and info.tierNum >= 5) and "⭐ " or ""
    print(string.format(
        "%s%s #%03d | %-24s | %-12s | %-22s | %8.2f kg | %-9s | Mutasi: %s",
        star, srcTag, totalLogged, userTag, tierStr, fishName:sub(1, 22), weightNum, flagStr, mutStr
    ))
end

print("=====================================================================================================")
print(string.format("🧪 [CATCH LOGGER v3.1] Aktif %ds | Katalog: %d ikan | Cek apakah Legend+ masuk lewat Event!", DURATION_SEC, catalogCount))
print("=====================================================================================================")

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
                        onStructuredCatch(desc.Name, a1, a3, a4)
                    end
                end)
            end)
            if ok and c then table.insert(conns, c) end
        end
    end
end)

-- Cek silang otomatis: kalau ada chat "obtained" (Legend+), cek apakah 2 detik terakhir juga masuk via RemoteEvent!
pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local c = TextChatService.MessageReceived:Connect(function(msg)
            if not active or not msg or not msg.Text then return end
            if string.find(msg.Text:lower(), "obtained") then
                local clean = msg.Text:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
                local pName = string.match(clean, "^(.-)%s+obtained%s+") or ""
                pName = pName:gsub("^%b[]%s*:?%s*", ""):match("^%s*(.-)%s*$") or ""
                task.delay(0.4, function()
                    if not active then return end
                    local rec = lastEventCatchByPlayer[string.lower(pName)]
                    local matched = (rec and (tick() - rec.t) < 3) and ("✅ ADA DI EVENT (" .. rec.fish .. " | " .. rec.tier .. ")") or "❌ TIDAK MASUK EVENT!"
                    print("🔎 [CEK LEGEND+] " .. clean .. "  ==>  " .. matched)
                end)
            end
        end)
        table.insert(conns, c)
    end
end)

local function stopProbe()
    if not active then return end
    active = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    table.clear(conns)
    print("🛑 [CATCH LOGGER v3.1] Selesai! Total event tercatat: " .. totalLogged)
end

if env then env._PokedexProbeStop = stopProbe end
task.delay(DURATION_SEC, stopProbe)
