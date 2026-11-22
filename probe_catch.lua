-- ==============================================================================
-- POKÉDEX CATCH LOGGER (TES FORMAT LOG F9 YANG RAPI)
-- Membaca tangkapan SEMUA player di seluruh server (Common -> Forgotten)
-- Memisahkan [ROD] vs [PET], menampilkan Berat (kg), Shiny, Mutasi, & field mentah
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
local DURATION_SEC = 90

local function formatMiniTable(tbl, depth)
    depth = depth or 0
    if type(tbl) ~= "table" then return tostring(tbl) end
    if depth >= 2 then return "{...}" end
    local parts = {}
    for k, v in pairs(tbl) do
        local ks = tostring(k)
        if ks ~= "PetUUID" then
            if type(v) == "table" then
                table.insert(parts, ks .. "=" .. formatMiniTable(v, depth + 1))
            elseif type(v) == "string" then
                table.insert(parts, ks .. '="' .. v .. '"')
            else
                table.insert(parts, ks .. "=" .. tostring(v))
            end
        end
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function extractExtraFields(meta)
    local known = { Weight = true, Shiny = true, Big = true, VariantId = true, Variant = true, Mutation = true, Attributes = true }
    local extra = {}
    for k, v in pairs(meta) do
        if not known[k] then
            extra[k] = v
        end
    end
    if type(meta.Attributes) == "table" then
        for k, v in pairs(meta.Attributes) do
            if k ~= "Source" and k ~= "PetId" and k ~= "PetUUID" then
                extra["Attr." .. tostring(k)] = v
            end
        end
    end
    if next(extra) ~= nil then
        return formatMiniTable(extra, 0)
    end
    return nil
end

local function onStructuredCatch(plr, pos, fishName, meta, extraArg)
    if not active then return end
    totalLogged = totalLogged + 1

    local isPet = type(meta.Attributes) == "table" and tostring(meta.Attributes.Source or "") == "PetFishing"
    local srcTag = isPet and "[PET]" or "[ROD]"

    local weightStr = string.format("%.2f kg", tonumber(meta.Weight) or 0)
    local tags = {}

    if meta.Shiny == true then table.insert(tags, "Shiny") end
    if meta.Big == true then table.insert(tags, "Big") end

    local mut = meta.VariantId or meta.Variant or meta.Mutation
    if mut and tostring(mut) ~= "" and tostring(mut) ~= "None" then
        table.insert(tags, tostring(mut))
    end
    if type(meta.Attributes) == "table" then
        local aMut = meta.Attributes.VariantId or meta.Attributes.Variant or meta.Attributes.Mutation
        if aMut and tostring(aMut) ~= "" and tostring(aMut) ~= "None" then
            table.insert(tags, tostring(aMut))
        end
    end

    local tagStr = #tags > 0 and table.concat(tags, ", ") or "Normal"
    local extraStr = extractExtraFields(meta)
    local suffix = extraStr and (" | extra=" .. extraStr) or ""

    local disp = plr.DisplayName or plr.Name
    local userTag = (disp ~= plr.Name) and string.format("%s (@%s)", disp, plr.Name) or ("@" .. plr.Name)

    print(string.format("%s #%03d | %-26s | %-24s | %9s | %s%s", srcTag, totalLogged, userTag, fishName, weightStr, tagStr, suffix))
end

print("===================================================================================")
print("🎣 [CATCH LOGGER RAPI] Aktif " .. DURATION_SEC .. " detik (Semua Player & Semua Tier!)")
print("   Format: [SUMBER] #No | Player | Nama Ikan | Berat | Varian/Mutasi")
print("===================================================================================")

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "🎣 Catch Logger Aktif",
        Text = "Log rapi semua tangkapan player aktif 90 detik di console F9!",
        Duration = 4
    })
end)

-- 1. Hubungkan ke RemoteEvent yang cocok dengan pola tangkapan (Player, Vector3, FishName, {Weight=...})
pcall(function()
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") then
            local ok, c = pcall(function()
                return desc.OnClientEvent:Connect(function(a1, a2, a3, a4, a5)
                    if not active then return end
                    if typeof(a1) == "Instance" and a1:IsA("Player")
                        and typeof(a2) == "Vector3"
                        and typeof(a3) == "string" and #a3 >= 2
                        and type(a4) == "table" and type(a4.Weight) == "number" then
                        onStructuredCatch(a1, a2, a3, a4, a5)
                    end
                end)
            end)
            if ok and c then
                table.insert(conns, c)
            end
        end
    end
end)

-- 2. Log pembanding Chat (khusus Legend+ supaya kita bisa bandingkan Big/Mutasi antara [ROD] & [CHAT])
pcall(function()
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local c = TextChatService.MessageReceived:Connect(function(msg)
            if not active or not msg or not msg.Text then return end
            if string.find(msg.Text:lower(), "obtained") then
                local clean = msg.Text:gsub("<[^>]+>", ""):gsub("^%s*(.-)%s*$", "%1")
                print("💬 [CHAT] " .. clean)
            end
        end)
        table.insert(conns, c)
    end
end)

local function stopProbe()
    if not active then return end
    active = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(conns)
    print("===================================================================================")
    print("🛑 [CATCH LOGGER] Selesai! Total tercatat: " .. totalLogged .. " tangkapan.")
    print("===================================================================================")
end

if env then env._PokedexProbeStop = stopProbe end
task.delay(DURATION_SEC, stopProbe)
