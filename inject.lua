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
-- 2. DETEKSI TIER (STACK PARSER TAG <font> NAMA IKAN) & PEMISAH VARIAN
-- ============================================================
local function classifyRgbColor(r, g, b)
    -- FORGOTTEN: Ungu / Violet / Magenta terang atau Putih-Prismatik
    if (r >= 150 and b >= 200 and g <= 155) or (r >= 225 and g >= 225 and b >= 225) then
        return "FORGOTTEN"
    -- SECRET: Teal / Cyan / Hijau Mint cerah (misal rgb(24, 255, 152) atau rgb(56, 220, 255))
    elseif (g >= 170 and b >= 110 and r <= 150) or (g >= 200 and r <= 110) then
        return "SECRET"
    -- MYTHIC: Merah terang / Crimson (misal rgb(255, 45, 45))
    elseif r >= 200 and g <= 115 and b <= 125 then
        return "MYTHIC"
    -- LEGENDARY: Oranye / Emas / Kuning (misal rgb(255, 185, 43))
    elseif r >= 200 and g >= 120 and b <= 110 then
        return "LEGENDARY"
    end
    return nil
end

local function parseColorAttr(tagStr)
    local rStr, gStr, bStr = tagStr:match('color%s*=%s*["\']%s*rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)%s*["\']')
    if rStr then
        return tonumber(rStr) or 0, tonumber(gStr) or 0, tonumber(bStr) or 0
    end
    local hex = tagStr:match('color%s*=%s*["\']%s*#?(%x%x%x%x%x%x)%s*["\']')
    if hex then
        return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
    end
    return nil
end

local function parseChanceNumber(cleanText)
    local chanceStr = cleanText:match("with%s+a%s+1%s+in%s+([%w%.,]+)%s+chance")
    if not chanceStr then return 0 end
    local upper = string.upper(chanceStr)
    local num = tonumber(string.match(upper, "[%d%.]+")) or 0
    if string.find(upper, "M") then
        return num * 1000000
    elseif string.find(upper, "K") then
        return num * 1000
    else
        local rawDigits = string.gsub(chanceStr, "[^%d]", "")
        return tonumber(rawDigits) or num
    end
end

local function tierFromOddsNum(effectiveNum)
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
    return "NORMAL"
end

local function isPureMutationText(txt)
    local low = string.lower(tostring(txt or "")):match("^%s*(.-)%s*$") or ""
    if low == "" then return false end
    for _, v in ipairs(KNOWN_VARIANTS) do
        if low == string.lower(v) then
            return true
        end
    end
    return false
end

local function determineTier(rawText, cleanText, baseFish, variantStr)
    -- PENTING: Hanya baca segmen SETELAH kata "obtained" agar warna nama pemain tidak terbaca!
    local afterObtained = rawText:match("[Oo]btained(.*)") or rawText
    local effectiveOdds = parseChanceNumber(cleanText)

    -- Cek apakah tangkapan punya mutasi non-Big/Shiny (seperti ALBINO/GHOST/CORRUPT/ELEMENTAL/HOLOGRAPHIC/DUSKBREAKER/GOLD)
    local hasColoredMutation = false
    if variantStr and variantStr ~= "" and string.lower(variantStr) ~= "none" then
        for tok in string.gmatch(string.lower(variantStr), "[^,]+") do
            local cleanTok = tok:match("^%s*(.-)%s*$") or ""
            if cleanTok ~= "" and cleanTok ~= "big" and cleanTok ~= "shiny" and cleanTok ~= "none" then
                hasColoredMutation = true
                break
            end
        end
    end

    -- 1. PARSER STACK TAG <font>: Melacak warna aktif di setiap potongan teks setelah "obtained"
    --    Kebal terhadap tag sejajar maupun bersarang (<font color="MUT">ALBINO</font> <font color="TIER">Ikan</font>)!
    local colorStack = {}
    local plainSegments = {}
    local fullPlain = ""
    local fontTagCount = 0
    local pos = 1
    local len = #afterObtained

    while pos <= len do
        local tagStart, tagEnd = afterObtained:find("<[^>]+>", pos)
        if not tagStart then
            local chunk = afterObtained:sub(pos)
            if #chunk > 0 then
                local top = colorStack[#colorStack]
                table.insert(plainSegments, {
                    startIdx = #fullPlain + 1,
                    endIdx = #fullPlain + #chunk,
                    text = chunk,
                    tier = top and top.tier or nil,
                    isWhite = top and top.isWhite or false,
                    depth = #colorStack
                })
                fullPlain = fullPlain .. chunk
            end
            break
        end

        if tagStart > pos then
            local chunk = afterObtained:sub(pos, tagStart - 1)
            local top = colorStack[#colorStack]
            table.insert(plainSegments, {
                startIdx = #fullPlain + 1,
                endIdx = #fullPlain + #chunk,
                text = chunk,
                tier = top and top.tier or nil,
                isWhite = top and top.isWhite or false,
                depth = #colorStack
            })
            fullPlain = fullPlain .. chunk
        end

        local tagStr = afterObtained:sub(tagStart, tagEnd)
        local lowerTag = string.lower(tagStr)
        if lowerTag:match("^<%s*/%s*font") then
            if #colorStack > 0 then
                table.remove(colorStack)
            end
        elseif lowerTag:match("^<%s*font%f[%s>]") then
            local r, g, b = parseColorAttr(tagStr)
            if r then
                fontTagCount = fontTagCount + 1
                local isW = (r >= 225 and g >= 225 and b >= 225)
                table.insert(colorStack, { tier = classifyRgbColor(r, g, b), isWhite = isW })
            else
                local prev = colorStack[#colorStack]
                table.insert(colorStack, { tier = prev and prev.tier or nil, isWhite = prev and prev.isWhite or false })
            end
        end

        pos = tagEnd + 1
    end

    -- 1A. Cari segmen warna TERAKHIR yang valid (bukan teks mutasi tunggal) di seluruh afterObtained
    --     (Menangani format Fish It: <font=MUT>ALBINO</font> <font=TIER>Ikan</font> MAUPUN <font=MUT>ALBINO Ikan</font> with a <font=TIER>1 in X</font>)
    local lastTierSeg = nil
    for i = #plainSegments, 1, -1 do
        local seg = plainSegments[i]
        local trimmedSeg = seg.text:match("^%s*(.-)%s*$") or ""
        if seg.tier and #trimmedSeg > 0 and not isPureMutationText(trimmedSeg) then
            -- Abaikan teks odds warna putih polos jika odds < 5 juta (bukan Forgotten asli)
            local isWhiteLowOdds = seg.isWhite and trimmedSeg:find("1%s+in%s+") and effectiveOdds > 0 and effectiveOdds < 5000000
            if not isWhiteLowOdds then
                lastTierSeg = seg
                break
            end
        end
    end

    -- 1B. Cari juga warna yang tepat membungkus baseFish (jika terpisah dari mutasi)
    local fishSeg = nil
    local targetLower = string.lower(tostring(baseFish or "")):match("^%s*(.-)%s*$") or ""
    if #targetLower >= 2 then
        local fullLower = string.lower(fullPlain)
        local matchPos = nil
        local searchFrom = 1
        while true do
            local s = string.find(fullLower, targetLower, searchFrom, true)
            if not s then break end
            matchPos = s
            searchFrom = s + 1
        end
        if matchPos then
            for _, seg in ipairs(plainSegments) do
                if matchPos >= seg.startIdx and matchPos <= seg.endIdx and seg.tier then
                    fishSeg = seg
                    break
                end
            end
        end
    end

    -- Pilih kandidat terbaik:
    -- Jika ada tag warna terpisah setelah mutasi (misal pada nama ikan atau pada odds "1 in X"), ambil lastTierSeg!
    local chosenSeg = lastTierSeg or fishSeg
    if chosenSeg and chosenSeg.tier then
        local chosenTier = chosenSeg.tier
        local segLower = string.lower(chosenSeg.text or "")
        local segContainsMutation = false
        if hasColoredMutation and variantStr then
            for tok in string.gmatch(string.lower(variantStr), "[^,]+") do
                local cleanTok = tok:match("^%s*(.-)%s*$") or ""
                if cleanTok ~= "" and cleanTok ~= "big" and cleanTok ~= "shiny" and cleanTok ~= "none" then
                    if string.find(segLower, cleanTok, 1, true) then
                        segContainsMutation = true
                        break
                    end
                end
            end
        end
        local isSharedMutTag = hasColoredMutation and (fontTagCount <= 1 or segContainsMutation)

        -- Pengaman anti-palsu FORGOTTEN: ikan Forgotten asli selalu >= 1 in 5M;
        -- jika warna putih/ungu muncul pada tangkapan bermutasi dengan odds < 5M (misal ALBINO/GHOST/CORRUPT 1 in 8K),
        -- itu pasti warna mutasi, bukan Forgotten!
        if chosenTier == "FORGOTTEN" and hasColoredMutation and effectiveOdds > 0 and effectiveOdds < 5000000 then
            local oddsFallback = tierFromOddsNum(effectiveOdds)
            if oddsFallback ~= "NORMAL" then
                return oddsFallback, "mut_rgb_ambiguous"
            end
        end

        if isSharedMutTag then
            -- Tag warna dipakai bersama dengan teks mutasi (bukan tag terpisah khusus nama ikan/odds) -> tandai ambiguous agar DB bisa bantu!
            return chosenTier, "mut_rgb_ambiguous"
        end
        return chosenTier, "fish_rgb"
    end

    -- 2. Fallback berdasarkan teks odds (hanya jika tidak ada warna tier di chat)
    if effectiveOdds > 0 then
        return tierFromOddsNum(effectiveOdds), "odds"
    end

    return "NORMAL", "none"
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
local function sendCatchToLocal(player, fish, variant, tier, displayName, userId, tierSource)
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
        tierSource = tierSource or "fish_rgb",
        bridgeVersion = 2,
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
                print(string.format("⚡ [LOKAL 0MS] Masuk: %s -> %s [%s/%s | %s]", mainDisplay, fish, tier, tostring(tierSource or "rgb"), variant))
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
        extractedPlayer, rawFishName = string.match(clean, "^(.-)%s+obtained%s+(.-)%s*%b()")
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
    local tier, tierSource = determineTier(rawText, clean, baseFish, variant)

    print(string.format("🐟 [TANGKAPAN] %s (@%s) -> %s [%s/%s | %s]", playerDisplayName, playerName, baseFish, tier, tostring(tierSource), variant))
    sendCatchToLocal(playerName, baseFish, variant, tier, playerDisplayName, playerUserId, tierSource)
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
