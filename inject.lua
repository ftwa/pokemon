-- ============================================================
-- POKÉDEX AUTO SKOR BRIDGE — PURE CHAT-ONLY LOKAL 0MS
-- 100% Murni Membaca Chat Tangkapan -> Kirim ke PokedexScoreboard.exe
-- Tanpa scan ReplicatedStorage, tanpa require(), tanpa getgc()
-- ============================================================
local cloneref = cloneref or function(o) return o end
local cclosure = newcclosure or function(f) return f end

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local TextChatService = cloneref(game:GetService("TextChatService"))
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
local LOCAL_CATCH_URL = "http://127.0.0.1:18420/api/local-catch"

print("============================================================")
print("  ⚡ POKÉDEX AUTO SKOR — PURE CHAT-ONLY LOKAL 0MS")
print("  💻 Target : " .. LOCAL_CATCH_URL)
print("============================================================")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "⚡ Pokédex Auto Skor",
        Text = "Aktif! Mode baca chat murni -> PokedexScoreboard.exe (0ms).",
        Duration = 4
    })
end)

-- ============================================================
-- 0. CLEANUP PROTEKSI DOUBLE-EXECUTE
-- ============================================================
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
-- 1. DAFTAR MUTASI RESMI FISH IT & NAMA IKAN DILINDUNGI
-- ============================================================
local KNOWN_VARIANTS = {
    "shiny", "big",
    "aurora", "galaxy", "sandy", "albino", "ghost", "haunted",
    "midnight", "corrupt", "radioactive", "holographic", "gemstone",
    "binary", "gold", "golden", "frozen", "glitch", "equinox",
    "disco", "elemental", "solar", "bloodmoon", "festive", "lightning",
    "fairy dust", "color burn", "crystalized", "moon fragment", "8-bit",
    "stone", "duskbreaker", "fire"
}
table.sort(KNOWN_VARIANTS, function(a, b) return #a > #b end)

-- Nama ikan yang mengandung kata mutasi agar TIDAK terpotong saat parsing
local PROTECTED_FISH_LIST = {
    "aurora butterfly fish",
    "aurora manatee",
    "aurora narwhal",
    "aurora jellyfish",
    "aurora seahorse",
    "aurora starfish",
    "aurora anglerfish",
    "bloodmoon whale",
    "brimstone catfish",
    "disco frogalloon",
    "elemental hydra",
    "elemental tempestray",
    "evolved enchant stone",
    "fairy wrasse",
    "festive dolphin",
    "frozen tundra",
    "ghost jellyfish",
    "ghost shark",
    "ghost worm fish",
    "golden dorado",
    "golden koi",
    "midnight blue wildes shark",
    "midnight stars squid",
    "pyroclast stonefish",
    "runic enchant stone",
    "solar koi",
    "solarflare koi",
    "stone fish",
    "stonefish",
    "sunfire carp"
}
table.sort(PROTECTED_FISH_LIST, function(a, b) return #a > #b end)

-- ============================================================
-- 2. DETEKSI TIER (RGB + HEX SETELAH "obtained") & PEMISAH VARIAN
-- ============================================================
local function classifyRgbColor(r, g, b)
    -- FORGOTTEN: Ungu / Violet / Magenta terang atau Putih-Prismatik
    if (r >= 150 and b >= 200 and g <= 155) or (r >= 225 and g >= 225 and b >= 225) then
        return "FORGOTTEN"
    -- SECRET: Teal / Cyan / Hijau Mint cerah (misal rgb(24, 255, 152) atau rgb(56, 220, 255))
    elseif (g >= 170 and b >= 110 and r <= 140) or (g >= 200 and r <= 100) then
        return "SECRET"
    -- MYTHIC: Merah terang / Crimson (misal rgb(255, 45, 45))
    elseif r >= 200 and g <= 100 and b <= 110 then
        return "MYTHIC"
    -- LEGENDARY: Oranye / Emas / Kuning (misal rgb(255, 185, 43))
    elseif r >= 200 and g >= 120 and b <= 100 then
        return "LEGENDARY"
    end
    return nil
end

local function determineTier(rawText, cleanText)
    -- PENTING: Hanya baca tag <font color=...> SETELAH kata "obtained"
    -- agar warna nama pemain (misal ungu rgb(107,50,124)) TIDAK salah dibaca sebagai tier ikan!
    local afterObtained = rawText:match("[Oo]btained(.*)") or rawText

    -- 1. Cek format rgb(R, G, B) yang dipakai Fish It modern
    for rStr, gStr, bStr in afterObtained:gmatch('color=["\']rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)["\']') do
        local tierFromRgb = classifyRgbColor(tonumber(rStr) or 0, tonumber(gStr) or 0, tonumber(bStr) or 0)
        if tierFromRgb then
            return tierFromRgb
        end
    end

    -- 2. Cek format HEX (#RRGGBB) jika ada
    for hex in afterObtained:gmatch('color=["\']#?(%x%x%x%x%x%x)["\']') do
        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        local tierFromHex = classifyRgbColor(r, g, b)
        if tierFromHex then
            return tierFromHex
        end
    end

    -- 3. Fallback berdasarkan teks odds (hanya jika tidak ada warna di chat)
    local chanceStr = cleanText:match("with%s+a%s+1%s+in%s+([%w%.,]+)%s+chance")
    if chanceStr then
        local upper = string.upper(chanceStr)
        local num = tonumber(string.match(upper, "[%d%.]+")) or 0
        local effectiveNum = num
        if string.find(upper, "M") then
            effectiveNum = num * 1000000
        elseif string.find(upper, "K") then
            effectiveNum = num * 1000
        else
            local rawDigits = string.gsub(chanceStr, "[^%d]", "")
            effectiveNum = tonumber(rawDigits) or num
        end

        if effectiveNum >= 10000000 then
            return "FORGOTTEN"
        elseif effectiveNum >= 250000 then
            return "SECRET"
        elseif effectiveNum >= 50000 then
            return "MYTHIC"
        elseif effectiveNum >= 5000 then
            return "LEGENDARY"
        elseif effectiveNum >= 1000 then
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

    -- 1. Kunci nama ikan yang mengandung kata mutasi dari belakang dulu
    for _, fishLower in ipairs(PROTECTED_FISH_LIST) do
        local pLen = #fishLower
        if #lowerTrimmed >= pLen and string.sub(lowerTrimmed, -pLen) == fishLower then
            local beforeIdx = #lowerTrimmed - pLen
            local charBefore = beforeIdx > 0 and string.sub(lowerTrimmed, beforeIdx, beforeIdx) or " "
            if not string.find(charBefore, "%w") then
                local lockedFish = string.sub(trimmed, #trimmed - pLen + 1)
                local prefixPart = beforeIdx > 0 and string.sub(trimmed, 1, beforeIdx) or ""
                if prefixPart ~= "" then
                    local leftover = extractVariantsFromText(prefixPart, detectedVariants)
                    if leftover ~= "" then
                        lockedFish = leftover .. " " .. lockedFish
                    end
                end
                local variantResult = #detectedVariants > 0 and table.concat(detectedVariants, ", ") or "None"
                return lockedFish, variantResult
            end
        end
    end

    -- 2. Parsing normal hanya dari KNOWN_VARIANTS yang valid
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
    if tier == "NORMAL" then return end

    local mainDisplay = tostring(displayName or player)
    local catchKey = string.format("%s_%s_%s_%s", mainDisplay, tostring(fish), tostring(variant), tostring(tier))
    local now = tick()
    if processedCatchHash[catchKey] and (now - processedCatchHash[catchKey]) < 0.6 then
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
-- 5. HOOK CHAT ROBLOX (MURNI BACA CHAT)
-- ============================================================
pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local c = TextChatService.MessageReceived:Connect(cclosure(function(msg)
            if msg and msg.Text then processChatMessage(msg.Text) end
        end))
        table.insert(activeConnections, c)
    else
        local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
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
