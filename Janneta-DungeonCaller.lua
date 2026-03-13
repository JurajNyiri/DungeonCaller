local ADDON_NAME, addon = ...

local Constants = addon.Constants
local Helpers = addon.Helpers
local UI = addon.UI
local DungeonLists = addon.DungeonLists

local REQUIRED_TANKS = Constants.REQUIRED_TANKS
local REQUIRED_HEALERS = Constants.REQUIRED_HEALERS
local REQUIRED_DPS = Constants.REQUIRED_DPS
local CLASS_TOKENS = Constants.CLASS_TOKENS
local Trim = Helpers.Trim
local Pluralize = Helpers.Pluralize

local db = Constants.NewDefaultDb()
local DEBUG_MEMBER_LOG = true
local SEND_CURRENT = false -- todo make a checkmark in ui

local function GetConfiguredWord(key, fallback)
    local value = db and db[key]
    if type(value) ~= "string" then
        return fallback
    end
    value = Trim(value)
    if value == "" then
        return fallback
    end
    return value
end

local function GetRoleWords()
    return {
        tankSingular = GetConfiguredWord("roleTankSingular", "tank"),
        tankPlural = GetConfiguredWord("roleTankPlural", "tanks"),
        healerSingular = GetConfiguredWord("roleHealerSingular", "healer"),
        healerPlural = GetConfiguredWord("roleHealerPlural", "healers"),
        dpsSingular = GetConfiguredWord("roleDpsSingular", "DPS"),
        dpsPlural = GetConfiguredWord("roleDpsPlural", "DPS"),
    }
end

local function CollectGroupMembers()
    local members = {}
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()
    local count = GetNumGroupMembers()

    if count == 0 then
        count = 1
        inRaid = false
        inGroup = false
    end

    for index = 1, count do
        local unit
        if inRaid then
            unit = "raid" .. index
        elseif inGroup then
            if index == 1 then
                unit = "player"
            else
                unit = "party" .. (index - 1)
            end
        else
            unit = "player"
        end

        if UnitExists(unit) then
            local memberName = UnitName(unit)
            local _, classToken = UnitClass(unit)
            local assignedRole = UnitGroupRolesAssigned(unit)

            table.insert(members, {
                name = memberName,
                role = assignedRole,
                classToken = classToken,
            })
        end
    end

    return members
end

local function BuildRoleSummary()
    local roleWords = GetRoleWords()
    local members = CollectGroupMembers()
    local tanks = 0
    local healers = 0
    local dps = 0
    local blClass = 0
    local unassigned = 0

    for _, member in ipairs(members) do
        local isBlClass = member.classToken and db.blClasses and db.blClasses[member.classToken] == true

        if isBlClass then
            blClass = blClass + 1
        end

        if member.role == "TANK" then
            tanks = tanks + 1
        elseif member.role == "HEALER" then
            healers = healers + 1
        elseif member.role == "DAMAGER" then
            dps = dps + 1
        end
    end

    local missingTank = math.max(REQUIRED_TANKS - tanks, 0)
    local missingHealer = math.max(REQUIRED_HEALERS - healers, 0)
    local missingDps = math.max(REQUIRED_DPS - dps, 0)
    local missingBl = 0
    if db.requireBl then
        missingBl = math.max(1 - blClass, 0)
    end

    local missing = {}
    if missingTank > 0 then
        table.insert(missing, Pluralize(missingTank, roleWords.tankSingular, roleWords.tankPlural))
    end
    if missingHealer > 0 then
        table.insert(missing, Pluralize(missingHealer, roleWords.healerSingular, roleWords.healerPlural))
    end
    if missingDps > 0 then
        table.insert(missing, Pluralize(missingDps, roleWords.dpsSingular, roleWords.dpsPlural))
    end

    local function BuildNeedMessage(missingListText)
        local needTemplate = db.needMessageTemplate
        if type(needTemplate) ~= "string" or needTemplate == "" then
            needTemplate = "Need %s"
        end
        if not string.find(needTemplate, "%s", 1, true) then
            needTemplate = needTemplate .. " %s"
        end
        local formatted = needTemplate:gsub("%%s", missingListText)
        return formatted
    end

    local message
    if #missing == 0 then
        message = db.readyMessage
        if type(message) ~= "string" or message == "" then
            message = "Party is ready: 1 tank, 1 healer, 3 DPS."
        end
    else
        message = BuildNeedMessage(table.concat(missing, ", "))

        if db.requireBl and missingBl > 0 then
            local blSuffix = db.needBlSuffix
            if type(blSuffix) ~= "string" or blSuffix == "" then
                blSuffix = " and BL"
            end
            message = message .. blSuffix
        end

        message = message .. "."
    end

    return {
        tanks = tanks,
        healers = healers,
        dps = dps,
        blClass = blClass,
        unassigned = unassigned,
        missingText = message,
        missingBl = missingBl,
        roleWords = roleWords,
    }
end

local function CanSendInChannel(channel, target)
    if channel == "PARTY" then
        return IsInGroup() or IsInRaid()
    end
    if channel == "RAID" then
        return IsInRaid()
    end
    if channel == "INSTANCE_CHAT" then
        local inInstance, instanceType = IsInInstance()
        return inInstance and (instanceType == "party" or instanceType == "raid")
    end
    if channel == "WHISPER" then
        return target and target ~= ""
    end
    return true
end

local function PostMessage(text)
    local channel = db.postChannel
    local target = Trim(db.whisperTarget)

    if not CanSendInChannel(channel, target) then
        print("Janneta Dungeon Caller: Selected channel is not available, sending to Say.")
        channel = "SAY"
    end

    if channel == "WHISPER" then
        SendChatMessage(text, channel, nil, target)
        return
    end

    SendChatMessage(text, channel)
end

local function GetEnabledBlClassNames()
    local names = {}
    for _, token in ipairs(CLASS_TOKENS) do
        if db.blClasses and db.blClasses[token] then
            table.insert(names, LOCALIZED_CLASS_NAMES_MALE[token] or token)
        end
    end
    if #names == 0 then
        return "none"
    end
    return table.concat(names, ", ")
end

local function SendRoleReport()
    local summary = BuildRoleSummary()
    local text = summary.missingText

    if SEND_CURRENT then
        text = text .. " Current: " ..
        Pluralize(summary.tanks, summary.roleWords.tankSingular, summary.roleWords.tankPlural) .. ", " ..
        Pluralize(summary.healers, summary.roleWords.healerSingular, summary.roleWords.healerPlural) .. ", " ..
        Pluralize(summary.dps, summary.roleWords.dpsSingular, summary.roleWords.dpsPlural)
    end

    PostMessage(text)
end

local function PrintDungeonLists()
    local dungeons = {}
    if type(DungeonLists.CollectCurrentExpansionDungeonNames) == "function" then
        dungeons = DungeonLists.CollectCurrentExpansionDungeonNames()
    end

    local raids = {}
    if type(DungeonLists.CollectRaidNames) == "function" then
        raids = DungeonLists.CollectRaidNames()
    end

    local mplus = {}
    if type(DungeonLists.CollectMythicPlusDungeonNames) == "function" then
        mplus = DungeonLists.CollectMythicPlusDungeonNames()
    end

    print("JDC Current expansion dungeons (" .. tostring(#dungeons) .. "): " .. (#dungeons > 0 and table.concat(dungeons, ", ") or "none found"))
    print("JDC Current expansion raids (" .. tostring(#raids) .. "): " .. (#raids > 0 and table.concat(raids, ", ") or "none found"))
    print("JDC Mythic+ rotation (" .. tostring(#mplus) .. "): " .. (#mplus > 0 and table.concat(mplus, ", ") or "none found"))
end

local function OnSlashCommand(msg)
    local command = string.lower(Trim(msg or ""))
    if command == "dungeons" then
        PrintDungeonLists()
        return
    end

    SendRoleReport()
end

SLASH_DUNGEONCALLER1 = "/dungeoncall"
SLASH_DUNGEONCALLER2 = "/dc"
SLASH_DUNGEONCALLER3 = "/dcaller"
SlashCmdList["DUNGEONCALLER"] = OnSlashCommand

local bootstrap = CreateFrame("Frame")
bootstrap:RegisterEvent("ADDON_LOADED")
bootstrap:RegisterEvent("PLAYER_LOGOUT")
bootstrap:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
        db = Helpers.EnsureDefaults()

        UI.SetDb(db)
        UI.Initialize(db)
    end
end)
