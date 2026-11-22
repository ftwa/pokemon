-- ============================================================
-- POKÉDEX AUTO SKOR BRIDGE — PURE NTFY.SH EDITION (ZERO LAG)
-- Kirim tangkapan Roblox Fish It langsung ke ntfy.sh Live Bus
-- ============================================================
local cloneref = cloneref or function(o) return o end
local cclosure = newcclosure or function(f) return f end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local TextChatService = cloneref(game:GetService("TextChatService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

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
print("  ⚡ POKÉDEX AUTO SKOR — PURE LOCAL 0MS BRIDGE (STABIL)")
print("  💻 Target    : " .. LOCAL_CATCH_URL)
print("  🚀 Anti-Lag  : " .. (ENABLE_ANTI_LAG_BOOST and "ON" or "OFF"))
print("============================================================")

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
-- 1. DAFTAR VARIAN / MUTASI & NAMA IKAN DILINDUNGI
-- ============================================================
local KNOWN_VARIANTS = {
    "shiny", "big", "giant", "tiny",
    "mutasi", "mutation", "mutated",
    "translucent", "dark", "electric", "sparkling", "rainbow",
    "aurora", "galaxy", "sandy", "albino", "ghost", "haunted",
    "midnight", "corrupt", "radioactive", "holographic", "gemstone",
    "binary", "gold", "golden", "frozen", "glitch", "equinox",
    "disco", "elemental", "solar", "bloodmoon", "festive", "lightning",
    "fairy dust", "color burn", "crystalized", "moon fragment", "8-bit", "stone", "duskbreaker"
}
table.sort(KNOWN_VARIANTS, function(a, b) return #a > #b end)

local PROTECTED_FISH_NAMES = {
    ["aurora manatee"] = true,
    ["aurora butterfly fish"] = true,
    ["aurora narwhal"] = true,
    ["aurora jellyfish"] = true,
    ["aurora seahorse"] = true,
    ["aurora starfish"] = true,
    ["aurora anglerfish"] = true,
    ["golden dorado"] = true,
    ["golden koi"] = true,
    ["ghost shark"] = true,
    ["ghost jellyfish"] = true,
    ["dark megalodon"] = true,
    ["electric eel"] = true,
    ["electric ray"] = true,
    ["rainbow trout"] = true,
    ["giant squid"] = true,
    ["solar koi"] = true,
    ["solarflare koi"] = true,
    ["fairy wrasse"] = true,
    ["stone fish"] = true,
    ["stonefish"] = true,
    ["crystal crab"] = true,
    ["crystal octopus"] = true,
    ["crystal goliath"] = true,
    ["crystal lancer"] = true,
    ["crystal salamander"] = true,
    ["crystalline behemoth"] = true,
    ["pyroclast stonefish"] = true,
    ["brimstone catfish"] = true,
    ["evolved enchant stone"] = true,
    ["runic enchant stone"] = true
}

-- ============================================================
-- 2. DETEKSI TIER & PEMISAH VARIAN
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

local function splitFishAndVariant(fullFishName)
    local detectedVariants = {}
    local cleanFish = fullFishName

    if PROTECTED_FISH_NAMES[string.lower(string.gsub(cleanFish, "^%s*(.-)%s*$", "%1"))] then
        return cleanFish, "None"
    end

    for _, v in ipairs(KNOWN_VARIANTS) do
        local trimmedCurrent = string.lower(string.match(cleanFish, "^%s*(.-)%s*$") or "")
        if PROTECTED_FISH_NAMES[trimmedCurrent] then
            break
        end
        local target = string.lower(v)
        local escapedTarget = string.gsub(target, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        while true do
            local lowerClean = string.lower(cleanFish)
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
                local originalText = string.sub(cleanFish, s, e)
                table.insert(detectedVariants, originalText)
                cleanFish = string.sub(cleanFish, 1, s - 1) .. " " .. string.sub(cleanFish, e + 1)
            else
                break
            end
        end
    end

    cleanFish = string.gsub(cleanFish, "%s+", " ")
    cleanFish = string.match(cleanFish, "^%s*(.-)%s*$") or fullFishName
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
