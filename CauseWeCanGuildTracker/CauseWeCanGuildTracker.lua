local addonName = ...
local CWCGT = CreateFrame("Frame", "CWCGTFrame")

local PREFIX = "CWCGT"
local POSITION_INTERVAL = 30
local ICON_SIZE = 14

CWCGT.players = {}
CWCGT.elapsed = 0
CWCGT.iconPool = {}
CWCGT.lastBankEntry = nil

local function PlayerIsInGuild()
    return (GetGuildInfo("player") ~= nil)
end

local function GetPlayerPositionData()
    local mapContinent = GetCurrentMapContinent()
    local mapZone = GetCurrentMapZone()

    SetMapToCurrentZone()
    local x, y = GetPlayerMapPosition("player")

    if not x or not y or (x == 0 and y == 0) then
        SetMapZoom(mapContinent, mapZone)
        return nil
    end

    local zone = GetRealZoneText() or "Unknown"
    local level = UnitLevel("player") or 0

    local data = {
        x = x,
        y = y,
        zone = zone,
        level = level,
        continent = GetCurrentMapContinent(),
        zoneIndex = GetCurrentMapZone(),
    }

    SetMapZoom(mapContinent, mapZone)
    return data
end

local function SendPositionUpdate()
    if not PlayerIsInGuild() then
        return
    end

    local info = GetPlayerPositionData()
    if not info then
        return
    end

    local message = string.format(
        "POS;%s;%s;%s;%s;%s;%s;%s",
        UnitName("player") or "Unknown",
        tostring(info.level),
        info.zone,
        tostring(info.continent or 0),
        tostring(info.zoneIndex or 0),
        string.format("%.4f", info.x),
        string.format("%.4f", info.y)
    )

    SendAddonMessage(PREFIX, message, "GUILD")
end

local function CreateIcon(index)
    local icon = CreateFrame("Frame", "CWCGTIcon" .. index, WorldMapDetailFrame)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints(true)
    icon.texture:SetTexture("Interface\\MINIMAP\\PartyRaidBlips")
    icon.texture:SetTexCoord(0, 0.125, 0.25, 0.375)

    icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    icon.text:SetPoint("TOP", icon, "BOTTOM", 0, -1)
    icon.text:SetTextColor(0.1, 1, 0.1)

    return icon
end

local function GetMapIcon(index)
    if not CWCGT.iconPool[index] then
        CWCGT.iconPool[index] = CreateIcon(index)
    end
    return CWCGT.iconPool[index]
end

local function HideUnusedIcons(startIndex)
    for i = startIndex, #CWCGT.iconPool do
        CWCGT.iconPool[i]:Hide()
    end
end

local function UpdateWorldMapIcons()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        HideUnusedIcons(1)
        return
    end

    local currentContinent = GetCurrentMapContinent()
    local currentZone = GetCurrentMapZone()

    local used = 0
    for name, data in pairs(CWCGT.players) do
        if data.continent == currentContinent and data.zoneIndex == currentZone then
            used = used + 1
            local icon = GetMapIcon(used)
            local mapWidth = WorldMapDetailFrame:GetWidth()
            local mapHeight = WorldMapDetailFrame:GetHeight()

            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", data.x * mapWidth, -data.y * mapHeight)
            icon.text:SetText(string.format("%s (%d)", name, data.level or 0))
            icon:Show()
        end
    end

    HideUnusedIcons(used + 1)
end

local function HandlePositionMessage(message)
    local marker, name, level, zone, continent, zoneIndex, x, y = strsplit(";", message)
    if marker ~= "POS" or not name then
        return
    end

    CWCGT.players[name] = {
        level = tonumber(level) or 0,
        zone = zone or "Unknown",
        continent = tonumber(continent) or 0,
        zoneIndex = tonumber(zoneIndex) or 0,
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        updatedAt = GetTime(),
    }

    UpdateWorldMapIcons()
end

local function PostDeathMessage()
    if not PlayerIsInGuild() then
        return
    end

    local info = GetPlayerPositionData()
    local zone = info and info.zone or (GetRealZoneText() or "Unknown")
    local level = UnitLevel("player") or 0
    local name = UnitName("player") or "Unknown"

    SendChatMessage(
        string.format("Guild alert: %s (level %d) died in %s.", name, level, zone),
        "GUILD"
    )
end

local function BuildBankMessage(entryType, playerName, itemLink, count, money)
    if entryType == "deposit" and itemLink then
        return string.format("Guild bank update: %s deposited %sx %s.", playerName, count or 1, itemLink)
    end
    if entryType == "withdraw" and itemLink then
        return string.format("Guild bank update: %s withdrew %sx %s.", playerName, count or 1, itemLink)
    end
    if entryType == "moneyDeposit" then
        return string.format("Guild bank update: %s deposited %s.", playerName, GetCoinTextureString(money or 0))
    end
    if entryType == "moneyWithdraw" then
        return string.format("Guild bank update: %s withdrew %s.", playerName, GetCoinTextureString(money or 0))
    end
    return nil
end

local function HandleGuildBankLog()
    if not PlayerIsInGuild() then
        return
    end

    local tab = GetCurrentGuildBankTab()
    if not tab then
        return
    end

    local num = GetNumGuildBankTransactions(tab)
    if not num or num < 1 then
        return
    end

    local entryType, playerName, itemLink, count, tab1, tab2, year, month, day, hour, money = GetGuildBankTransaction(tab, 1)
    if not entryType or not playerName then
        return
    end

    local id = table.concat({entryType, playerName, tostring(itemLink), tostring(count), tostring(year), tostring(month), tostring(day), tostring(hour), tostring(money)}, "|")
    if CWCGT.lastBankEntry == id then
        return
    end

    CWCGT.lastBankEntry = id

    local msg = BuildBankMessage(entryType, playerName, itemLink, count, money)
    if msg then
        SendChatMessage(msg, "GUILD")
    end
end

local function PurgeExpiredPlayers()
    local now = GetTime()
    for name, data in pairs(CWCGT.players) do
        if now - (data.updatedAt or 0) > POSITION_INTERVAL * 3 then
            CWCGT.players[name] = nil
        end
    end
end

CWCGT:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        else
            RegisterAddonMessagePrefix(PREFIX)
        end
        SendPositionUpdate()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel = ...
        if prefix == PREFIX and channel == "GUILD" then
            HandlePositionMessage(message)
        end
    elseif event == "PLAYER_DEAD" then
        PostDeathMessage()
    elseif event == "GUILDBANKLOG_UPDATE" then
        HandleGuildBankLog()
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMapIcons()
    end
end)

CWCGT:SetScript("OnUpdate", function(_, elapsed)
    CWCGT.elapsed = CWCGT.elapsed + elapsed
    if CWCGT.elapsed >= POSITION_INTERVAL then
        CWCGT.elapsed = 0
        SendPositionUpdate()
        PurgeExpiredPlayers()
        UpdateWorldMapIcons()
    end
end)

CWCGT:RegisterEvent("PLAYER_LOGIN")
CWCGT:RegisterEvent("CHAT_MSG_ADDON")
CWCGT:RegisterEvent("PLAYER_DEAD")
CWCGT:RegisterEvent("GUILDBANKLOG_UPDATE")
CWCGT:RegisterEvent("WORLD_MAP_UPDATE")
