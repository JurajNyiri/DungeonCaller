local ADDON_NAME, addon = ...

local Constants = addon.Constants
local Helpers = addon.Helpers
local UI = addon.UI
local DungeonLists = addon.DungeonLists
local MinimapButton = addon.MinimapButton

local REQUIRED_TANKS = Constants.REQUIRED_TANKS
local REQUIRED_HEALERS = Constants.REQUIRED_HEALERS
local REQUIRED_DPS = Constants.REQUIRED_DPS
local CLASS_TOKENS = Constants.CLASS_TOKENS
local Trim = Helpers.Trim
local Pluralize = Helpers.Pluralize
local NormalizeNameForLookup = Helpers.NormalizeNameForLookup
local MPLUS_MIN_KEY_LEVEL = 2
local MPLUS_MAX_KEY_LEVEL = 99

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

local function BuildCaseInsensitiveTokenPattern(token)
    local escaped = token:gsub("(%W)", "%%%1")
    return escaped:gsub("%a", function(letter)
        return "[" .. string.lower(letter) .. string.upper(letter) .. "]"
    end)
end

local function ReplaceTokenCaseInsensitive(text, token, replacement)
    local safeReplacement = tostring(replacement or "")
    return text:gsub(BuildCaseInsensitiveTokenPattern(token), function()
        return safeReplacement
    end)
end

local function SanitizeMythicPlusKeyLevel(value)
    local numeric = tonumber(value)
    if not numeric then
        return MPLUS_MIN_KEY_LEVEL
    end

    numeric = math.floor(numeric)
    if numeric < MPLUS_MIN_KEY_LEVEL then
        return MPLUS_MIN_KEY_LEVEL
    end
    if numeric > MPLUS_MAX_KEY_LEVEL then
        return MPLUS_MAX_KEY_LEVEL
    end

    return numeric
end

local function GetSelectedDifficulty()
    local difficulty = db.selectedDifficulty
    if type(difficulty) ~= "string" or difficulty == "" then
        return "Normal"
    end
    return difficulty
end

local function GetSelectedDungeonByDifficulty(difficulty)
    if difficulty == "Mythic+" then
        local mplusDungeon = db.selectedMythicPlusDungeon
        if type(mplusDungeon) == "string" then
            return mplusDungeon
        end
        return ""
    end

    local dungeon = db.selectedDungeon
    if type(dungeon) == "string" then
        return dungeon
    end
    return ""
end

local function GetPlayerSpecializationRole()
    local specializationIndex = GetSpecialization()
    local role = GetSpecializationRole(specializationIndex)
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end
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
            if unit == "player" and not inGroup and not inRaid and (assignedRole == nil or assignedRole == "NONE") then
                assignedRole = GetPlayerSpecializationRole() or assignedRole
            end

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
            needTemplate = "Need %NEEDED% for %DUNGEON% (%DIFFICULTY%%LEVEL%)%BL%."
        end

        local difficulty = GetSelectedDifficulty()
        local selectedDungeon = GetSelectedDungeonByDifficulty(difficulty)
        local levelText = ""
        if difficulty == "Mythic+" then
            levelText = tostring(SanitizeMythicPlusKeyLevel(db.mythicPlusKeyLevel))
        end

        local needsBlInsert = db.requireBl and missingBl > 0
        local blSuffix = db.needBlSuffix
        if type(blSuffix) ~= "string" or blSuffix == "" then
            blSuffix = " including BL"
        end
        local formatted = needTemplate
        formatted = ReplaceTokenCaseInsensitive(formatted, "%NEEDED%", missingListText)
        formatted = ReplaceTokenCaseInsensitive(formatted, "%DUNGEON%", selectedDungeon)
        formatted = ReplaceTokenCaseInsensitive(formatted, "%DIFFICULTY%", difficulty)
        formatted = ReplaceTokenCaseInsensitive(formatted, "%LEVEL%", levelText)
        formatted = ReplaceTokenCaseInsensitive(formatted, "%BL%", needsBlInsert and blSuffix or "")

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
        print("Dungeon Caller: Selected channel is not available, sending to Say.")
        channel = "SAY"
    end

    if channel == "WHISPER" then
        SendChatMessage(text, channel, nil, target)
        return
    end

    SendChatMessage(text, channel)
end

local latestPreparedLfgTitleKey = ""

local function MakePreparedLfgTitleKey(dungeonName, selectedDifficulty)
    return NormalizeNameForLookup(dungeonName) .. "|" .. NormalizeNameForLookup(selectedDifficulty)
end

local function MarkPreparedLfgTitle(dungeonName, selectedDifficulty)
    latestPreparedLfgTitleKey = MakePreparedLfgTitleKey(dungeonName, selectedDifficulty)
end

local function IsLfgTitlePreparedForSelection(dungeonName, selectedDifficulty)
    local key = MakePreparedLfgTitleKey(dungeonName, selectedDifficulty)
    if key == "|" then
        return false
    end
    return latestPreparedLfgTitleKey == key
end

local function NotifyLfgSelectionChanged(dungeonName, selectedDifficulty)
    if NormalizeNameForLookup(dungeonName) == "" then
        latestPreparedLfgTitleKey = ""
        return
    end
end

local function ActivityMatchesSelectedDifficulty(activityInfo, selectedDifficulty)
    if selectedDifficulty == "Mythic+" then
        return activityInfo.isMythicPlusActivity == true
    end
    if selectedDifficulty == "Mythic" then
        return activityInfo.isMythicActivity == true and activityInfo.isMythicPlusActivity ~= true
    end
    if selectedDifficulty == "Heroic" then
        return activityInfo.isHeroicActivity == true
    end
    if selectedDifficulty == "Normal" then
        return activityInfo.isNormalActivity == true
    end

    return true
end

local function FindLfgActivityByDungeonName(dungeonName, selectedDifficulty)
    local target = NormalizeNameForLookup(dungeonName)
    for _, activityID in ipairs(C_LFGList.GetAvailableActivities() or {}) do
        local info = C_LFGList.GetActivityInfoTable(activityID)
        if ActivityMatchesSelectedDifficulty(info, selectedDifficulty) then
            local shortName = NormalizeNameForLookup(info.shortName)
            local fullName = NormalizeNameForLookup(info.fullName)
            local fullNameWithoutShortName = fullName
            if shortName ~= "" then
                fullNameWithoutShortName = Trim(fullName:gsub(shortName, "", 1))
            end

            if fullNameWithoutShortName == target then
                return activityID, info
            end
        end
    end
    return nil, nil
end

local function GetEncounterJournalDifficultyID(selectedDifficulty)
    if selectedDifficulty == "Normal" then
        return 1
    end
    if selectedDifficulty == "Heroic" then
        return 2
    end
    if selectedDifficulty == "Mythic" or selectedDifficulty == "Mythic+" then
        return 23
    end

    return nil
end

local function ResolveEncounterJournalInstanceID(mapID)
    local journalInstanceID = C_EncounterJournal.GetInstanceForGameMap(mapID)
    if type(journalInstanceID) == "number" then
        return journalInstanceID
    end

    return nil
end

local function EnsureEncounterJournalLoaded()
    if EncounterJournal then
        return true
    end

    ToggleEncounterJournal()

    if EncounterJournal then
        return true
    end

    return EncounterJournal ~= nil
end

local function OpenEncounterJournalForDungeon(dungeonName, selectedDifficulty, mythicPlusKeyLevel)
    local mapID
    local journalDifficultyID = GetEncounterJournalDifficultyID(selectedDifficulty)

    if DungeonLists and type(DungeonLists.GetJournalMapIDForDungeon) == "function" then
        mapID = DungeonLists.GetJournalMapIDForDungeon(dungeonName, selectedDifficulty)
    end

    if not mapID then
        print("Dungeon Caller: Could not resolve a map for '" .. tostring(dungeonName) .. "' on " .. tostring(selectedDifficulty) .. ".")
        return false
    end

    local journalInstanceID = ResolveEncounterJournalInstanceID(mapID)
    if not journalInstanceID then
        print("Dungeon Caller: Could not resolve an Adventure Guide entry for '" .. tostring(dungeonName) .. "'.")
        return false
    end

    if not EnsureEncounterJournalLoaded() or type(EncounterJournal_OpenJournal) ~= "function" then
        print("Dungeon Caller: Could not load the Adventure Guide.")
        return false
    end

    if selectedDifficulty == "Mythic+" then
        C_EncounterJournal.SetPreviewMythicPlusLevel(SanitizeMythicPlusKeyLevel(mythicPlusKeyLevel))
    end

    if type(journalDifficultyID) ~= "number" then
        journalDifficultyID = nil
    end

    EncounterJournal_OpenJournal(journalDifficultyID, journalInstanceID)
    if type(journalDifficultyID) == "number" then
        EJ_SetDifficulty(journalDifficultyID)
    end
    return true
end

local function TrySetEntryTitleViaApi(activityID, activityInfo)
    return pcall(C_LFGList.SetEntryTitle, activityID, activityInfo.groupFinderActivityGroupID)
end

local function CreateLfgGroupForDungeon(dungeonName, selectedDifficulty)
    if C_LFGList.HasActiveEntryInfo() then
        print("Dungeon Caller: You already have an active LFG listing. Remove it first.")
        return false
    end

    local activityID, activityInfo = FindLfgActivityByDungeonName(dungeonName, selectedDifficulty)
    if not activityID then
        print("Dungeon Caller: Could not find an LFG activity for '" .. tostring(dungeonName) .. "' on " .. selectedDifficulty .. ".")
        return false
    end

    local shouldPrepareTitle = LFGListFrame.EntryCreation.Name:GetText() == "" or not IsLfgTitlePreparedForSelection(dungeonName, selectedDifficulty)

    if shouldPrepareTitle then
        local ok, _ = TrySetEntryTitleViaApi(activityID, activityInfo)
        if ok then
            MarkPreparedLfgTitle(dungeonName, selectedDifficulty)
        end
        return ok
    end

    local isCrossFactionListing = activityInfo and activityInfo.allowCrossFaction == true
    local createData = {
        activityIDs = { activityID },
        isAutoAccept = false,
        isPrivateGroup = false,
        newPlayerFriendly = false,
        isCrossFactionListing = isCrossFactionListing,
        requiredItemLevel = 0,
        requiredDungeonScore = 0,
        requiredPvpRating = 0,
        generalPlaystyle = Enum.LFGEntryGeneralPlaystyle.FunSerious
    }

    local createResult = C_LFGList.CreateListing(createData)
    if type(createResult) == "table" then
        return createResult.success == true
    end
    return createResult == true
end

addon.CreateLfgGroupForDungeon = CreateLfgGroupForDungeon
addon.OpenEncounterJournalForDungeon = OpenEncounterJournalForDungeon
addon.IsLfgTitlePreparedForSelection = IsLfgTitlePreparedForSelection
addon.NotifyLfgSelectionChanged = NotifyLfgSelectionChanged

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

local function PrintLockedDungeonList()
    local lockedDungeons = DungeonLists.CollectLockedDungeonNames()
    local formatted = {}
    for _, entry in ipairs(lockedDungeons) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
            local difficultyText = tostring(entry.difficultyName or "Unknown")
            table.insert(formatted, entry.name .. " (" .. difficultyText .. ")")
        elseif type(entry) == "string" and entry ~= "" then
            table.insert(formatted, entry)
        end
    end

    print("JDC Locked dungeons (" .. tostring(#formatted) .. "): " .. (#formatted > 0 and table.concat(formatted, ", ") or "none found"))
end

local function OnSlashCommand(msg)
    local command = string.lower(Trim(msg or ""))
    if command == "dungeons" then
        PrintDungeonLists()
        return
    end
    if command == "lockout" then
        PrintLockedDungeonList()
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
        MinimapButton.Initialize()
    end
end)
