local addonName = ...
local addonTitle = "Mark and Ping"

local addonChatPrefix = addonName .. "Alert"
local messagePrefix = "|cFFFFDB58[" .. addonTitle .. "]|r "
local defaultVolume = "medium"
local currentVolume = defaultVolume
local soundFiles = { -- 5339002 on Retail | 259371 on WoWHead
    high = "Interface\\AddOns\\" .. addonName .. "\\Media\\ping_sound_high.ogg",
    medium = "Interface\\AddOns\\" .. addonName .. "\\Media\\ping_sound_medium.ogg",
    low = "Interface\\AddOns\\" .. addonName .. "\\Media\\ping_sound_low.ogg"
}
local markerID = 1 -- Star - Markers 1 to 8
local markerChatIcon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t " -- Star
local maxCharges = 5
local currentCharges = maxCharges
local rechargeTime = 10 -- Seconds to regenerate a charge
local rechargeTimerActive = false

C_ChatInfo.RegisterAddonMessagePrefix(addonChatPrefix)

local function SetVolume(volume)
    if soundFiles[volume] then
        currentVolume = volume
        MarkAndPingDB.volume = volume
        print("[" .. addonName .. "] Volume set to: " .. volume)
    else
        print("[" .. addonName .. "] Invalid volume level. Use: high, medium, or low.")
    end
end

local function PlayPingSound()
    local soundFile = soundFiles[currentVolume]
    if soundFile then
        PlaySoundFile(soundFile, "SFX")
    else
        print(messagePrefix .. "Sound file not found for volume: " .. currentVolume)
    end
end

local function GetUnitLink(unit)
    local targetName = UnitName(unit)
    local targetLink = "|Hunit:" .. UnitGUID(unit) .. ":" .. targetName .. "|h[" .. targetName .. "]|h"
    return targetLink
end

local function SendPingMessage(sender, unitLink)
    print(messagePrefix .. sender .. " marked: " .. markerChatIcon .. unitLink)
end

local function NotifyGroup(unitLink)
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(addonChatPrefix, unitLink, "PARTY")
    else
        SendPingMessage(UnitName("player"), unitLink)
    end
end

local function RechargeCharge()
    if currentCharges < maxCharges then
        currentCharges = currentCharges + 1

        if currentCharges < maxCharges then
            C_Timer.After(rechargeTime, RechargeCharge)
        else
            rechargeTimerActive = false
        end
    end
end

local function UseCharge()
    if currentCharges > 0 then
        currentCharges = currentCharges - 1

        if not rechargeTimerActive then
            rechargeTimerActive = true
            C_Timer.After(rechargeTime, RechargeCharge)
        end

        return true
    else
        print(messagePrefix .. "You have to wait before sending more pings.")
        return false
    end
end

local function GetUnitColor(unit)
    if UnitIsPlayer(unit) then
        local className, classFile = UnitClass(unit)
        if classFile then
            local classColor = RAID_CLASS_COLORS[classFile]
            return string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
        end
    else
        local reaction = UnitReaction(unit, "player")

        if reaction >= 5 then
            return "|cFF00FF00" -- Green
        elseif reaction == 4 then
            return "|cFFFFFF00" -- Yellow
        elseif reaction <= 3 then
            return "|cFFFF0000" -- Red
        end
    end

    return "|cFFFFFFFF"
end

function MarkAndNotify(unit)
    if UnitExists(unit) and UseCharge() then
        if not GetRaidTargetIndex(unit) then
            SetRaidTarget(unit, markerID)
        end
        PlayPingSound()

        local unitLink = GetUnitColor(unit) .. GetUnitLink(unit) .. "|r"
        NotifyGroup(unitLink)
    end
end

local function LoadSettings()
    if not MarkAndPingDB then
        MarkAndPingDB = {}
    end
    currentVolume = MarkAndPingDB.volume or defaultVolume
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function(self, event)
    LoadSettings()
    _G.BINDING_HEADER_MARK_AND_PING = addonTitle
    _G.BINDING_NAME_MARK_AND_PING_KEY = addonTitle .. " Key"
    self:UnregisterEvent("PLAYER_LOGIN")
    self = nil
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == addonChatPrefix then
        local senderName = sender:match("([^%-]+)")
        SendPingMessage(senderName, message)
        local name, realm = UnitFullName("player", true)
        local fullPlayerName = name .. "-" .. realm
        if sender ~= fullPlayerName then
            PlayPingSound()
        end
    end
end)

SLASH_MPING1 = "/mping"
SlashCmdList["MPING"] = function(msg)
    local args = {strsplit(" ", msg)}
    local command = args[1]
    local value = args[2]

    if command == "volume" and value then
        SetVolume(value)
    elseif command == "ping" then
        PlayPingSound()
    else
        print(messagePrefix .. "Usage:")
        print("/mping volume [high|medium|low] - Set the volume level")
        print("/mping ping - Play the ping sound")
    end
end
