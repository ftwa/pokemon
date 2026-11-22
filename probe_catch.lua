-- ==============================================================================
-- POKÉDEX PROBE CATCH — DIAGNOSTIK READ-ONLY (LOG CONSOLE F9 SAJA)
-- Mengecek format tangkapan player lain yang direplikasi server (selain Chat)
-- Otomatis berhenti sendiri setelah 45 detik agar console tetap bersih!
-- ==============================================================================
local cloneref = cloneref or function(o) return o end
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local StarterGui = cloneref(game:GetService("StarterGui"))
local LocalPlayer = Players.LocalPlayer

local env = getgenv and getgenv()
if env and env._PokedexProbeStop then
    pcall(env._PokedexProbeStop)
end

local conns = {}
local active = true
local remoteHitCounts = {}
local MAX_HITS_PER_REMOTE = 4
local DURATION_SEC = 45

local IGNORE_REMOTE_PATTERNS = {
    "ping", "time", "clock", "sync", "pos", "move", "walk", "swim", "boat",
    "camera", "look", "mouse", "input", "steer", "weather", "day", "night",
    "leaderboard", "shop", "trade", "quest", "sound", "music", "audio",
    "footstep", "splash", "bubble", "particle", "anim", "cast", "charge",
    "bobber", "line", "rope", "rodswing", "stamina", "heartbeat"
}

local INTERESTING_REMOTE_PATTERNS = {
    "fish", "catch", "caught", "obtain", "reel", "text", "effect", "notif",
    "popup", "reward", "drop", "item", "display", "show", "overhead",
    "announce", "broadcast", "replicate", "trophy", "journal", "index", "bag"
}

local function formatVal(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "Instance" then
        return string.format("<%s:%s>", v.ClassName, v.Name)
    elseif t == "string" then
        local s = v:gsub("\n", " ")
        if #s > 110 then s = s:sub(1, 110) .. "..." end
        return '"' .. s .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        if depth >= 2 then return "{...}" end
        local parts = {}
        local n = 0
        for k, val in pairs(v) do
            n = n + 1
            if n <= 10 then
                table.insert(parts, tostring(k) .. "=" .. formatVal(val, depth + 1))
            end
        end
        if n > 10 then table.insert(parts, "...+" .. (n - 10)) end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return "<" .. t .. ":" .. tostring(v) .. ">"
    end
end

local function isIgnoredRemote(nameLower)
    for _, p in ipairs(IGNORE_REMOTE_PATTERNS) do
        if nameLower:find(p, 1, true) then return true end
    end
    return false
end

local function isInterestingRemote(nameLower)
    for _, p in ipairs(INTERESTING_REMOTE_PATTERNS) do
        if nameLower:find(p, 1, true) then return true end
    end
    return false
end

local function argsLookLikeOtherPlayerCatch(args)
    local hasOtherPlayer = false
    local hasFishData = false
    for _, a in ipairs(args) do
        local t = typeof(a)
        if t == "Instance" then
            if a:IsA("Player") and a ~= LocalPlayer then
                hasOtherPlayer = true
            elseif a:IsA("Model") and Players:GetPlayerFromCharacter(a) and Players:GetPlayerFromCharacter(a) ~= LocalPlayer then
                hasOtherPlayer = true
            end
        elseif t == "table" then
            if a.Fish or a.FishId or a.ItemId or a.FishName or a.Tier or a.Rarity or a.Weight or a.VariantId or a.Mutation or a.TextData or a.Text then
                hasFishData = true
            end
            if a.Player and a.Player ~= LocalPlayer then hasOtherPlayer = true end
        elseif t == "string" then
            local s = a:lower()
            if s:find("kg") or s:find("caught") or s:find("obtain") or s:find("fish") or s:find("rare") or s:find("epic") or s:find("common") or s:find("uncommon") then
                hasFishData = true
            end
        end
    end
    return hasOtherPlayer or hasFishData
end

print("=============================================================")
print("🧪 [PROBE CATCH] Mulai pantau selama " .. DURATION_SEC .. " detik...")
print("   Berdiri dekat player lain yang sedang mancing, lalu lihat log F9!")
print("=============================================================")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🧪 Probe Catch Aktif",
        Text = "Memantau tangkapan player lain selama 45 detik. Buka F9 untuk lihat log!",
        Duration = 4
    })
end)

-- ==============================================================================
-- 1. PANTAU REMOTE EVENT (OnClientEvent) YANG MASUK DARI SERVER
-- ==============================================================================
local hookedRemotes = 0
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            local nLower = string.lower(desc.Name)
            local fullPath = desc:GetFullName()
            if not isIgnoredRemote(nLower) then
                local interesting = isInterestingRemote(nLower) or isInterestingRemote(string.lower(fullPath))
                local ok, c = pcall(function()
                    return desc.OnClientEvent:Connect(function(...)
                        if not active then return end
                        local args = { ... }
                        if not interesting and not argsLookLikeOtherPlayerCatch(args) then
                            return
                        end
                        local cnt = (remoteHitCounts[fullPath] or 0) + 1
                        if cnt > MAX_HITS_PER_REMOTE then return end
                        remoteHitCounts[fullPath] = cnt

                        local formatted = {}
                        for i = 1, #args do
                            table.insert(formatted, string.format("arg%d=%s", i, formatVal(args[i], 0)))
                        end
                        print(string.format("📡 [REMOTE #%d] %s | %s", cnt, desc.Name, table.concat(formatted, " | ")))
                    end)
                end)
                if ok and c then
                    table.insert(conns, c)
                    hookedRemotes = hookedRemotes + 1
                end
            end
        end
    end
end)
print(string.format("📡 Terhubung ke %d RemoteEvent kandidat (read-only).", hookedRemotes))

-- ==============================================================================
-- 2. PANTAU KARAKTER & BILLBOARDGUI PLAYER LAIN DI WORKSPACE
-- ==============================================================================
local charHitCount = 0
local MAX_CHAR_HITS = 25

local function watchCharacter(plr, char)
    if not char or plr == LocalPlayer then return end
    local c = char.DescendantAdded:Connect(function(obj)
        if not active or charHitCount >= MAX_CHAR_HITS then return end
        local cls = obj.ClassName
        if cls == "Tool" or cls == "BillboardGui" or cls == "TextLabel" or (cls == "Model" and obj.Parent == char) then
            task.defer(function()
                if not obj or not obj.Parent then return end
                local extra = ""
                if cls == "TextLabel" then
                    local txt = tostring(obj.Text or ""):gsub("<[^>]+>", ""):gsub("\n", " ")
                    if #txt < 2 or txt == plr.Name or txt == plr.DisplayName then return end
                    extra = ' Text="' .. txt:sub(1, 80) .. '"'
                elseif cls == "Tool" or cls == "Model" then
                    local attrs = obj:GetAttributes()
                    if next(attrs) ~= nil then
                        extra = " Attrs=" .. formatVal(attrs, 0)
                    end
                elseif cls == "BillboardGui" then
                    local labels = {}
                    for _, d in ipairs(obj:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
                            table.insert(labels, d.Text:gsub("<[^>]+>", ""))
                        end
                    end
                    if #labels == 0 then return end
                    extra = " Labels=" .. formatVal(labels, 0)
                end
                charHitCount = charHitCount + 1
                print(string.format("🧍 [CHAR #%d] Player=%s | %s:%s%s", charHitCount, plr.DisplayName, cls, obj.Name, extra))
            end)
        end
    end)
    table.insert(conns, c)
end

local function watchPlayer(plr)
    if plr == LocalPlayer then return end
    if plr.Character then watchCharacter(plr, plr.Character) end
    table.insert(conns, plr.CharacterAdded:Connect(function(ch) watchCharacter(plr, ch) end))

    -- Cek juga leaderstats (misal Caught bertambah)
    pcall(function()
        local ls = plr:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                if stat:IsA("IntValue") or stat:IsA("NumberValue") or stat:IsA("StringValue") then
                    local c = stat.Changed:Connect(function(newVal)
                        if not active then return end
                        print(string.format("📊 [STAT] Player=%s | %s = %s", plr.DisplayName, stat.Name, tostring(newVal)))
                    end)
                    table.insert(conns, c)
                end
            end
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    watchPlayer(p)
end
table.insert(conns, Players.PlayerAdded:Connect(watchPlayer))

-- ==============================================================================
-- 3. AUTO-STOP SETELAH 45 DETIK
-- ==============================================================================
local function stopProbe()
    if not active then return end
    active = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
    print("=============================================================")
    print("🛑 [PROBE CATCH] Selesai! Silakan screenshot/copy log F9 di atas.")
    print("=============================================================")
end

if env then env._PokedexProbeStop = stopProbe end

task.delay(DURATION_SEC, stopProbe)
