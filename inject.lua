-- ============================================================
-- POKÉDEX AUTO SKOR BRIDGE — PURE LOCAL 0MS EDITION (v3)
-- Auto-Sync Semua Mutasi & Nama Ikan Langsung dari Game!
-- Kirim tangkapan Roblox Fish It langsung ke PokedexScoreboard.exe
-- ============================================================
local cloneref = cloneref or function(o) return o end
local cclosure = newcclosure or function(f) return f end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))

local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (getgenv and getgenv().request)
    or (getgenv and getgenv().http_request)

if not httpRequest then
    warn("⚠️ [POKÉDEX AUTO SKOR] Executor Anda tidak mendukung HTTP Request!")
end

-- ============================================================
-- KONFIGURASI TARGET LOKAL 0MS (POKÉDEX SCOREBOARD DESKTOP .EXE)
-- ============================================================
local LOCAL_CATCH_URL       = "http://127.0.0.1:18420/api/local-catch"
local ENABLE_ANTI_LAG_BOOST = true

print("============================================================")
print("  ⚡ POKÉDEX AUTO SKOR — PURE LOCAL 0MS BRIDGE (v3 AUTO-SYNC)")
print("  💻 Target    : " .. LOCAL_CATCH_URL)
print("  🚀 Anti-Lag  : " .. (ENABLE_ANTI_LAG_BOOST and "ON" or "OFF"))
print("============================================================")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "⚡ Pokédex Auto Skor v3",
        Text = "Aktif! Mutasi & ikan otomatis sinkron dari game (Lokal 0ms).",
        Duration = 4
    })
end)

-- ============================================================
-- 0. ANTI-LAG & CLEANUP PROTEKSI DOUBLE-EXECUTE
-- ============================================================
if ENABLE_ANTI_LAG_BOOST then
    task.spawn(function()
        pcall(function()
            local Lighting = cloneref(game:GetService("Lighting"))
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("BloomEffect") then
                    v.Enabled = false
                end
            end
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
            end
        end)
    end)
end

local processedCatchHash = {}
local activeConnections = {}
local isBridgeActive = true

local env = getgenv and getgenv()
local CLEANUP_KEY = "_PokedexAutoSkorBridge_v1"
if env and env[CLEANUP_KEY] then
    pcall(env[CLEANUP_KEY])
end

task.spawn(function()
    while isBridgeActive do
        task.wait(45)
        if not isBridgeActive then break end
        pcall(function()
            local now = tick()
            for k, t in pairs(processedCatchHash) do
                if (now - t) > 15 then
                    processedCatchHash[k] = nil
                end
            end
            collectgarbage("collect")
        end)
    end
end)

-- ============================================================
-- 1. DAFTAR VARIAN / MUTASI + AUTO-SYNC LANGSUNG DARI GAME
-- ============================================================
local KNOWN_VARIANTS = {
    "shiny", "big", "giant", "tiny",
    "mutasi", "mutation", "mutated",
    "translucent", "dark", "electric", "sparkling", "rainbow",
    "aurora", "galaxy", "sandy", "albino", "ghost", "haunted",
    "midnight", "corrupt", "radioactive", "holographic", "gemstone",
    "binary", "gold", "golden", "frozen", "glitch", "equinox",
    "disco", "elemental", "solar", "bloodmoon", "festive", "lightning",
    "fairy dust", "color burn", "crystalized", "moon fragment", "8-bit",
    "stone", "duskbreaker"
}
local KNOWN_VARIANTS_SET = {}
for _, v in ipairs(KNOWN_VARIANTS) do
    KNOWN_VARIANTS_SET[string.lower(v)] = true
end
table.sort(KNOWN_VARIANTS, function(a, b) return #a > #b end)

-- Nama ikan yang dilindungi agar tidak terpotong kata mutasi (otomatis ditambah semua ikan dari game!)
local GAME_FISH_SET = {}
local GAME_FISH_LIST = {
    "aurora butterfly fish", "aurora manatee", "aurora narwhal", "aurora jellyfish",
    "aurora seahorse", "aurora starfish", "aurora anglerfish", "bloodmoon whale",
    "brimstone catfish", "crystal crab", "crystal goliath", "crystal lancer",
    "crystal octopus", "crystal salamander", "crystalline behemoth", "dark megalodon",
    "dark megalofriend", "dark pumpkin appafish", "dark seahorse", "disco frogalloon",
    "electric eel", "electric ray", "elemental hydra", "elemental tempestray",
    "evolved enchant stone", "fairy wrasse", "festive dolphin", "frozen tundra",
    "ghost jellyfish", "ghost shark", "ghost worm fish", "giant squid",
    "golden dorado", "golden koi", "midnight blue wildes shark", "midnight stars squid",
    "pyroclast stonefish", "rainbow comet shark", "rainbow trout", "runic enchant stone",
    "solar koi", "solarflare koi", "stone fish", "stonefish"
}
for _, fn in ipairs(GAME_FISH_LIST) do
    GAME_FISH_SET[string.lower(fn)] = true
end
table.sort(GAME_FISH_LIST, function(a, b) return #a > #b end)

local function registerVariantName(rawName)
    if type(rawName) ~= "string" then return end
    local clean = string.lower(string.match(rawName, "^%s*(.-)%s*$") or "")
    if #clean < 2 or #clean > 32 then return end
    if clean == "none" or clean == "normal" or clean == "default" or clean == "variants" or clean == "mutations" then return end
    if not KNOWN_VARIANTS_SET[clean] then
        KNOWN_VARIANTS_SET[clean] = true
        table.insert(KNOWN_VARIANTS, clean)
    end
end

local function registerGameFishName(rawName)
    if type(rawName) ~= "string" then return end
    local clean = string.lower(string.match(rawName, "^%s*(.-)%s*$") or "")
    if #clean < 3 or #clean > 60 then return end
    if not GAME_FISH_SET[clean] then
        GAME_FISH_SET[clean] = true
        table.insert(GAME_FISH_LIST, clean)
    end
end

local function isExcludedNonFishType(rawType)
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

-- Auto-Sync semua Mutasi (Variants) & Nama Ikan (Items) langsung dari ReplicatedStorage + Memori Game
task.spawn(function()
    local startVarCount = #KNOWN_VARIANTS
    local startFishCount = #GAME_FISH_LIST
    local newlyFoundVars = {}

    local function trackVariant(rawName)
        if type(rawName) ~= "string" then return end
        local clean = string.lower(string.match(rawName, "^%s*(.-)%s*$") or "")
        if #clean < 2 or #clean > 32 then return end
        if clean == "none" or clean == "normal" or clean == "default" or clean == "variants" or clean == "mutations" or clean == "shiny" or clean == "big" then return end
        if clean:find("table:") or clean:find("rbxassetid") or clean:find("^%d+$") then return end
        if not KNOWN_VARIANTS_SET[clean] then
            KNOWN_VARIANTS_SET[clean] = true
            table.insert(KNOWN_VARIANTS, clean)
            table.insert(newlyFoundVars, rawName)
        end
    end

    local function scanVariantTable(tbl, depth)
        if type(tbl) ~= "table" or depth > 3 then return end
        local d = (type(tbl.Data) == "table") and tbl.Data or tbl
        local vName = d.Name or d.DisplayName or d.Title
        local vType = string.lower(tostring(d.Type or tbl.Type or ""))
        if type(vName) == "string" and (vType:find("variant") or vType:find("mutat") or tbl.PriceMultiplier or tbl.SellMultiplier or tbl.Multiplier or tbl.Chance or d.Icon or d.Color) then
            trackVariant(vName)
        end
        for k, v in pairs(tbl) do
            if type(v) == "table" and k ~= "Data" then
                local sub = (type(v.Data) == "table") and v.Data or v
                if type(sub.Name) == "string" then
                    trackVariant(sub.Name)
                elseif type(k) == "string" and #k >= 2 and #k <= 28 then
                    if v.PriceMultiplier or v.SellMultiplier or v.Multiplier or v.Color or v.Chance or v.Data then
                        trackVariant(k)
                    end
                end
                scanVariantTable(v, depth + 1)
            end
        end
    end

    pcall(function()
        for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
            if inst:IsA("ModuleScript") then
                local nLower = string.lower(inst.Name)
                local pLower = inst.Parent and string.lower(inst.Parent.Name) or ""

                -- 1) Scan Mutasi / Variants resmi game
                if nLower:find("variant") or nLower:find("mutat") or pLower:find("variant") or pLower:find("mutat") then
                    pcall(function()
                        local mod = require(inst)
                        if type(mod) == "table" then
                            scanVariantTable(mod, 0)
                        end
                    end)
                end

                -- 2) Scan Nama Ikan resmi game agar tidak pernah terpotong mutasi baru
                if nLower:find("fish") or nLower:find("item") or pLower == "items" or pLower:find("fish") then
                    pcall(function()
                        local mod = require(inst)
                        if type(mod) == "table" then
                            local d = (type(mod.Data) == "table") and mod.Data or mod
                            local rawType = d.Type or mod.Type or ""
                            if type(d.Name) == "string" and (d.Icon or mod.Icon) and not isExcludedNonFishType(rawType) then
                                registerGameFishName(d.Name)
                            end
                            for _, v in pairs(mod) do
                                if type(v) == "table" then
                                    local sub = (type(v.Data) == "table") and v.Data or v
                                    local sType = sub.Type or v.Type or ""
                                    if type(sub.Name) == "string" and (sub.Icon or v.Icon) and not isExcludedNonFishType(sType) then
                                        registerGameFishName(sub.Name)
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- 3) Scan memori GC untuk tabel Variant / Mutation yang dimuat di runtime
    local getgcFunc = getgc or (debug and debug.getgc)
    if getgcFunc then
        pcall(function()
            for _, obj in ipairs(getgcFunc(true)) do
                if type(obj) == "table" then
                    local d = (type(obj.Data) == "table") and obj.Data or obj
                    local oType = string.lower(tostring(d.Type or obj.Type or ""))
                    if (oType == "variant" or oType == "mutation") and type(d.Name) == "string" then
                        trackVariant(d.Name)
                    end
                end
            end
        end)
    end

    table.sort(KNOWN_VARIANTS, function(a, b) return #a > #b end)
    table.sort(GAME_FISH_LIST, function(a, b) return #a > #b end)
    local addedVariants = #KNOWN_VARIANTS - startVarCount
    local addedFish = #GAME_FISH_LIST - startFishCount
    print(string.format("✅ [AUTO-SYNC] Total %d mutasi (+%d baru dari game) & %d ikan (+%d dari game) siap!", #KNOWN_VARIANTS, addedVariants, #GAME_FISH_LIST, addedFish))
    if #newlyFoundVars > 0 then
        table.sort(newlyFoundVars)
        print("🧬 [MUTASI BARU TERDETEKSI] " .. table.concat(newlyFoundVars, ", "))
    end
end)

-- ============================================================
-- 2. DETEKSI TIER & PEMISAH VARIAN (EXACT FISH + AUTO MUTATION)
-- ============================================================
local function determineTier(rawText, cleanText)
    local hex = rawText:match('color=["\']#?(%x%x%x%x%x%x)["\']')
    if hex then
        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0

        if (r > 160 and b > 200 and g < 150) or (r > 150 and b > 230) then
            return "FORGOTTEN"
        elseif (g > 170 and (b > 110 or r < 130)) or (r > 110 and b > 140 and g < 110) then
            return "SECRET"
        elseif r > 200 and g < 90 then
            return "MYTHIC"
        elseif r > 190 and g > 110 and b < 90 then
            return "LEGENDARY"
        end
    end

    local chanceStr = cleanText:match("with%s+a%s+1%s+in%s+([%w%.,]+)%s+chance")
    if chanceStr then
        local upper = string.upper(chanceStr)
        local rawDigits = string.gsub(chanceStr, "[^%d]", "")
        local rawNum = tonumber(rawDigits) or 0
        local num = tonumber(string.match(upper, "[%d%.]+")) or 0

        if (string.find(upper, "M") and num >= 10) or rawNum >= 10000000 then
            return "FORGOTTEN"
        elseif string.find(upper, "M") or (string.find(upper, "K") and num >= 400) or rawNum >= 400000 then
            return "SECRET"
        elseif (string.find(upper, "K") and num >= 50) or rawNum >= 50000 then
            return "MYTHIC"
        elseif (string.find(upper, "K") and num >= 5) or rawNum >= 5000 then
            return "LEGENDARY"
        elseif (string.find(upper, "K") and num >= 1) or rawNum >= 1000 then
            return "RARE"
        end
    end

    return "NORMAL"
end

local function extractVariantsFromText(textChunk, detectedVariants)
    local cleanChunk = textChunk
    for _, v in ipairs(KNOWN_VARIANTS) do
        local target = string.lower(v)
        local escapedTarget = string.gsub(target, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        while true do
            local lowerClean = string.lower(cleanChunk)
            local s, e = string.find(lowerClean, "%f[%w]" .. escapedTarget .. "%f[%W]")
            if not s then
                s, e = string.find(lowerClean, target, 1, true)
                if s then
                    local charBefore = s > 1 and string.sub(lowerClean, s - 1, s - 1) or " "
                    local charAfter = e < #lowerClean and string.sub(lowerClean, e + 1, e + 1) or " "
                    if string.find(charBefore, "%w") or string.find(charAfter, "%w") then
                        s = nil
                    end
                end
            end

            if s and e then
                local originalText = string.sub(cleanChunk, s, e)
                table.insert(detectedVariants, originalText)
                cleanChunk = string.sub(cleanChunk, 1, s - 1) .. " " .. string.sub(cleanChunk, e + 1)
            else
                break
            end
        end
    end
    cleanChunk = string.gsub(cleanChunk, "%s+", " ")
    return string.match(cleanChunk, "^%s*(.-)%s*$") or ""
end

local function splitFishAndVariant(fullFishName)
    local detectedVariants = {}
    local trimmed = string.match(tostring(fullFishName or ""), "^%s*(.-)%s*$") or ""
    local lowerTrimmed = string.lower(trimmed)

    -- 1. Cocokkan nama ikan resmi dari belakang (terpanjang dulu) -> 100% kebal mutasi baru!
    for _, fishLower in ipairs(GAME_FISH_LIST) do
        local pLen = #fishLower
        if #lowerTrimmed >= pLen and string.sub(lowerTrimmed, -pLen) == fishLower then
            local beforeIdx = #lowerTrimmed - pLen
            local charBefore = beforeIdx > 0 and string.sub(lowerTrimmed, beforeIdx, beforeIdx) or " "
            if not string.find(charBefore, "%w") then
                local lockedFish = string.sub(trimmed, #trimmed - pLen + 1)
                local prefixPart = beforeIdx > 0 and string.sub(trimmed, 1, beforeIdx) or ""
                if prefixPart ~= "" then
                    local leftover = extractVariantsFromText(prefixPart, detectedVariants)
                    -- Hanya mutasi valid dari daftar/game (KNOWN_VARIANTS) yang dihitung;
                    -- sisa kata non-mutasi tetap menjadi bagian nama ikan agar tidak jadi mutasi palsu!
                    if leftover ~= "" then
                        lockedFish = leftover .. " " .. lockedFish
                    end
                end
                local variantResult = #detectedVariants > 0 and table.concat(detectedVariants, ", ") or "None"
                return lockedFish, variantResult
            end
        end
    end

    -- 2. Fallback parsing normal jika nama ikan belum ada di daftar
    local cleanFish = extractVariantsFromText(trimmed, detectedVariants)
    if cleanFish == "" then cleanFish = trimmed end
    local variantResult = #detectedVariants > 0 and table.concat(detectedVariants, ", ") or "None"
    return cleanFish, variantResult
end

-- ============================================================
-- 3. KIRIM TANGKAPAN MURNI KE LOKAL 0MS (POKÉDEX SCOREBOARD .EXE)
-- ============================================================
local function sendCatchToLocal(player, fish, variant, tier, displayName, userId)
    if not httpRequest then return end
    if tier == "NORMAL" or tier == "RARE" then return end

    local mainDisplay = tostring(displayName or player)
    local catchKey = string.format("%s_%s_%s_%s", mainDisplay, tostring(fish), tostring(variant), tostring(tier))
    local now = tick()
    if processedCatchHash[catchKey] and (now - processedCatchHash[catchKey]) < 1.8 then
        return
    end
    processedCatchHash[catchKey] = now

    local eventId = string.format("loc_%d_%d", os.time(), math.random(10000, 99999))
    local tsMs = os.time() * 1000
    local jsonBody = HttpService:JSONEncode({
        id = eventId,
        type = "SYNC_CATCH",
        user = mainDisplay,
        displayName = mainDisplay,
        username = tostring(player or mainDisplay),
        userId = userId or 0,
        fish = fish,
        variant = variant,
        tier = tier,
        kategori = tier,
        source = "roblox_local",
        timestamp = tsMs
    })

    task.spawn(function()
        local ok, err = pcall(function()
            local res = httpRequest({
                Url = LOCAL_CATCH_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonBody
            })
            if res and (res.StatusCode == 200 or res.StatusCode == 201) then
                print(string.format("⚡ [LOKAL 0MS] Masuk: %s -> %s [%s | %s]", mainDisplay, fish, tier, variant))
            else
                warn("⚠️ [LOKAL] PokedexScoreboard.exe belum terbuka! (status: " .. tostring(res and res.StatusCode or "offline") .. ")")
            end
        end)
        if not ok then
            warn("⚠️ [LOKAL] HTTP error: " .. tostring(err))
        end
    end)
end

-- ============================================================
-- 4. PARSER CHAT TANGKAPAN IKAN
-- ============================================================
local function processChatMessage(rawText)
    if not rawText or type(rawText) ~= "string" then return end
    if not string.find(rawText:lower(), "obtained") then return end

    local clean = string.gsub(rawText, "<[^>]+>", "")
    clean = string.gsub(clean, "^(%b[]%s*:?%s*)+", "")
    clean = string.match(clean, "^%s*(.-)%s*$") or clean

    local targetPlayerObj = Players.LocalPlayer
    local playerName = targetPlayerObj and targetPlayerObj.Name or "Unknown"
    local playerDisplayName = targetPlayerObj and targetPlayerObj.DisplayName or playerName
    local playerUserId = targetPlayerObj and targetPlayerObj.UserId or 0

    local extractedPlayer, rawFishName = string.match(clean, "^(.-)%s+obtained%s+an?%s+(.-)%s*%b()")
    if not extractedPlayer then
        extractedPlayer, rawFishName = string.match(clean, "^(.-)%s+obtained%s+an?%s+(.-)%s+with")
    end
    if not extractedPlayer then
        extractedPlayer, rawFishName = string.match(clean, "^(.-)%s+obtained%s+an?%s+(.-)$")
    end

    if extractedPlayer then
        local trimmedName = string.match(extractedPlayer, "^%s*@*(.-)%s*$") or ""
        local trimmedLower = string.lower(trimmedName)
        local foundPlr = Players:FindFirstChild(trimmedName)
        if not foundPlr then
            for _, p in ipairs(Players:GetPlayers()) do
                if string.lower(p.Name) == trimmedLower or string.lower(p.DisplayName) == trimmedLower then
                    foundPlr = p
                    break
                end
            end
        end
        if foundPlr then
            playerName = foundPlr.Name
            playerDisplayName = foundPlr.DisplayName or foundPlr.Name
            playerUserId = foundPlr.UserId or 0
        else
            playerName = trimmedName
            playerDisplayName = trimmedName
            playerUserId = 0
        end
    end

    if not rawFishName then return end

    local baseFish, variant = splitFishAndVariant(rawFishName)
    local tier = determineTier(rawText, clean)

    print(string.format("🐟 [TANGKAPAN] %s (@%s) -> %s [%s | %s]", playerDisplayName, playerName, baseFish, tier, variant))
    sendCatchToLocal(playerName, baseFish, variant, tier, playerDisplayName, playerUserId)
end

-- ============================================================
-- 5. HOOK CHAT ROBLOX (MODERN & LEGACY)
-- ============================================================
pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local c = TextChatService.MessageReceived:Connect(cclosure(function(msg)
            if msg and msg.Text then processChatMessage(msg.Text) end
        end))
        table.insert(activeConnections, c)
    else
        local legacy = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if legacy then
            local onMsg = legacy:FindFirstChild("OnMessageDoneFiltering")
            if onMsg then
                local c = onMsg.OnClientEvent:Connect(cclosure(function(data)
                    if data and data.Message then processChatMessage(data.Message) end
                end))
                table.insert(activeConnections, c)
            end
        end
    end
end)

-- ============================================================
-- 6. CLEANUP HANDLER
-- ============================================================
local function stopMonitor()
    isBridgeActive = false
    for _, conn in ipairs(activeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(activeConnections)
    print("🧹 [POKÉDEX AUTO SKOR] Instance sebelumnya dibersihkan.")
end

if env then
    env[CLEANUP_KEY] = stopMonitor
end
