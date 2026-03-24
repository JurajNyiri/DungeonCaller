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

local ITEM_UPGRADE_TRACK_LABELS = {
    [972] = "Veteran",
    [973] = "Champion",
    [974] = "Hero",
    [975] = "Myth",
}

local EQUIP_LOC_TO_SLOT_IDS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_SHIELD = { 17 },
}

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
local dungeonLootCache = {}
-- Background loot scans use API calls directly and avoid loading the Blizzard Encounter Journal UI.
local ENABLE_ENCOUNTER_JOURNAL_LOOT_SCAN = true
local journalTooltipMoneyWorkaroundRegistered = false

local function SecureBlizzardCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    return securecallfunction(func, ...)
end

local function FrameNameContainsEncounterJournal(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return false
    end

    local frameName = frame:GetName()
    return type(frameName) == "string" and string.find(frameName, "EncounterJournal", 1, true) ~= nil
end

local function TooltipBelongsToEncounterJournal(tooltip)
    local visited = {}

    local function ScanFrameChain(frame)
        while frame and not visited[frame] do
            visited[frame] = true

            if FrameNameContainsEncounterJournal(frame) then
                return true
            end

            if type(frame.GetParent) ~= "function" then
                break
            end
            frame = frame:GetParent()
        end

        return false
    end

    if ScanFrameChain(tooltip) then
        return true
    end

    local owner = tooltip and type(tooltip.GetOwner) == "function" and tooltip:GetOwner() or nil
    while owner and not visited[owner] do
        if ScanFrameChain(owner) then
            return true
        end

        if type(owner.GetOwner) ~= "function" then
            break
        end
        owner = owner:GetOwner()
    end

    return false
end

local function SuppressEncounterJournalSellPriceLine(tooltip, data)
    if not TooltipBelongsToEncounterJournal(tooltip) then
        return
    end
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return
    end

    local sellPriceLineType = type(Enum) == "table"
        and type(Enum.TooltipDataLineType) == "table"
        and Enum.TooltipDataLineType.SellPrice
        or nil
    if sellPriceLineType == nil then
        return
    end

    -- Narrow workaround for Blizzard's 12.x secret-money tooltip issue in the Encounter Journal.
    for index = #data.lines, 1, -1 do
        local lineData = data.lines[index]
        if type(lineData) == "table" and lineData.type == sellPriceLineType then
            table.remove(data.lines, index)
        end
    end
end

local function RegisterJournalTooltipMoneyWorkaround()
    if journalTooltipMoneyWorkaroundRegistered then
        return
    end
    if type(TooltipDataProcessor) ~= "table" or type(TooltipDataProcessor.AddTooltipPreCall) ~= "function" then
        return
    end
    if type(Enum) ~= "table" or type(Enum.TooltipDataType) ~= "table" or Enum.TooltipDataType.Item == nil then
        return
    end

    TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, SuppressEncounterJournalSellPriceLine)
    journalTooltipMoneyWorkaroundRegistered = true
end

local function IsEncounterJournalVisible()
    return EncounterJournal and EncounterJournal:IsShown() == true
end

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
    if type(mapID) ~= "number" then
        return nil
    end

    local journalInstanceID = type(C_EncounterJournal) == "table"
        and SecureBlizzardCall(C_EncounterJournal.GetInstanceForGameMap, mapID)
        or nil
    if type(journalInstanceID) == "number" then
        return journalInstanceID
    end

    return nil
end

local function LoadEncounterJournalUi()
    if EncounterJournal then
        return true
    end

    if type(EncounterJournal_LoadUI) == "function" then
        securecallfunction(EncounterJournal_LoadUI)
    end
    if EncounterJournal then
        return true
    end

    return EncounterJournal ~= nil
end

local function EnsureEncounterJournalLoaded()
    if LoadEncounterJournalUi() then
        return true
    end

    if type(ToggleEncounterJournal) == "function" then
        securecallfunction(ToggleEncounterJournal)
    end

    return EncounterJournal ~= nil
end

local function GetCurrentPlayerClassAndSpecIDs()
    local _, _, classID = UnitClass("player")
    local specializationIndex = GetSpecialization()
    local specID = 0

    if specializationIndex and specializationIndex > 0 then
        specID = select(1, GetSpecializationInfo(specializationIndex)) or 0
    end

    return classID, specID
end

local function BuildDungeonLootCacheKey(dungeonName, selectedDifficulty, classID, specID, mythicPlusKeyLevel)
    local cacheKey = NormalizeNameForLookup(dungeonName) .. "|" .. NormalizeNameForLookup(selectedDifficulty)
        .. "|" .. tostring(classID or 0) .. "|" .. tostring(specID or 0)

    if selectedDifficulty == "Mythic+" then
        cacheKey = cacheKey .. "|" .. tostring(SanitizeMythicPlusKeyLevel(mythicPlusKeyLevel))
    end

    return cacheKey
end

local function GetInventorySlotIDsForEquipLocation(equipLoc)
    if equipLoc == "INVTYPE_WEAPON" then
        if type(CanDualWield) == "function" and CanDualWield() then
            return { 16, 17 }
        end
        return { 16 }
    end

    return EQUIP_LOC_TO_SLOT_IDS[equipLoc]
end

local function GetItemLevel(itemReference)
    if not itemReference then
        return nil
    end

    local itemLevel = C_Item.GetDetailedItemLevelInfo(itemReference)

    if type(itemLevel) == "number" and itemLevel > 0 then
        return itemLevel
    end

    return nil
end

local function GetUpgradeTrackInfo(itemReference)
    if not itemReference or type(C_Item) ~= "table" or type(C_Item.GetItemUpgradeInfo) ~= "function" then
        return nil, nil, nil, nil
    end

    local upgradeInfo = C_Item.GetItemUpgradeInfo(itemReference)
    if type(upgradeInfo) ~= "table" then
        return nil, nil, nil, nil
    end

    local trackLabel = upgradeInfo.trackString
    if type(trackLabel) == "string" then
        trackLabel = Trim(trackLabel)
    end
    if trackLabel == "" then
        trackLabel = nil
    end

    local trackID = type(upgradeInfo.trackStringID) == "number" and upgradeInfo.trackStringID or nil
    if not trackLabel and trackID then
        trackLabel = ITEM_UPGRADE_TRACK_LABELS[trackID]
    end

    return trackLabel, trackID, tonumber(upgradeInfo.currentLevel), tonumber(upgradeInfo.maxLevel)
end

local function BuildEquippedItemComparisons(slotIDs)
    local comparisons = {}
    if type(slotIDs) ~= "table" then
        return comparisons
    end

    for _, slotID in ipairs(slotIDs) do
        local equippedItemLink = GetInventoryItemLink("player", slotID)
        table.insert(comparisons, {
            slotID = slotID,
            itemLink = equippedItemLink,
            itemLevel = GetItemLevel(equippedItemLink) or 0,
        })
    end

    return comparisons
end

local function IsLootItemHigherLevelThanEquipped(itemLevel, comparisons)
    if type(itemLevel) ~= "number" or itemLevel <= 0 then
        return false
    end
    if type(comparisons) ~= "table" or #comparisons == 0 then
        return false
    end

    for _, comparison in ipairs(comparisons) do
        if itemLevel > (comparison.itemLevel or 0) then
            return true
        end
    end

    return false
end

local function CaptureEncounterJournalState()
    local classID, specID
    if type(EJ_GetLootFilter) == "function" then
        classID, specID = SecureBlizzardCall(EJ_GetLootFilter)
    end

    return {
        instanceID = EncounterJournal and EncounterJournal.instanceID or nil,
        encounterID = EncounterJournal and EncounterJournal.encounterID or nil,
        difficultyID = type(EJ_GetDifficulty) == "function" and SecureBlizzardCall(EJ_GetDifficulty) or nil,
        classID = classID,
        specID = specID,
    }
end

local function RestoreEncounterJournalState(state)
    if type(state) ~= "table" then
        return
    end

    if type(state.instanceID) == "number" and type(EJ_SelectInstance) == "function" then
        SecureBlizzardCall(EJ_SelectInstance, state.instanceID)
    end
    if type(state.difficultyID) == "number" and type(EJ_SetDifficulty) == "function" then
        SecureBlizzardCall(EJ_SetDifficulty, state.difficultyID)
    end
    if type(state.encounterID) == "number" and type(EJ_SelectEncounter) == "function" then
        SecureBlizzardCall(EJ_SelectEncounter, state.encounterID)
    end
    if type(EJ_SetLootFilter) == "function" and type(state.classID) == "number" then
        SecureBlizzardCall(EJ_SetLootFilter, state.classID, state.specID or 0)
    end
end

local function BuildDungeonLootItemsForPlayer(dungeonName, selectedDifficulty, mythicPlusKeyLevel)
    if not ENABLE_ENCOUNTER_JOURNAL_LOOT_SCAN then
        return {}
    end

    local classID, specID = GetCurrentPlayerClassAndSpecIDs()
    local cacheKey = BuildDungeonLootCacheKey(dungeonName, selectedDifficulty, classID, specID, mythicPlusKeyLevel)
    local cachedItems = dungeonLootCache[cacheKey]
    if type(cachedItems) == "table" then
        return cachedItems
    end

    if IsEncounterJournalVisible() then
        return {}
    end

    if type(C_EncounterJournal) ~= "table" or type(C_EncounterJournal.GetLootInfoByIndex) ~= "function" then
        return {}
    end

    local mapID
    if DungeonLists and type(DungeonLists.GetJournalMapIDForDungeon) == "function" then
        mapID = DungeonLists.GetJournalMapIDForDungeon(dungeonName, selectedDifficulty)
    end
    if not mapID then
        return {}
    end

    local journalInstanceID = ResolveEncounterJournalInstanceID(mapID)
    if not journalInstanceID then
        return {}
    end

    if type(EJ_SelectInstance) ~= "function" then
        return {}
    end

    local previousState = CaptureEncounterJournalState()
    local journalDifficultyID = GetEncounterJournalDifficultyID(selectedDifficulty)
    local items = {}
    local canCache = true

    SecureBlizzardCall(EJ_SelectInstance, journalInstanceID)

    if type(EJ_SetDifficulty) == "function" and type(journalDifficultyID) == "number" then
        SecureBlizzardCall(EJ_SetDifficulty, journalDifficultyID)
    end
    if type(EJ_SetLootFilter) == "function" and type(classID) == "number" then
        SecureBlizzardCall(EJ_SetLootFilter, classID, specID or 0)
    end
    if selectedDifficulty == "Mythic+" and type(C_EncounterJournal) == "table" and type(C_EncounterJournal.SetPreviewMythicPlusLevel) == "function" then
        SecureBlizzardCall(C_EncounterJournal.SetPreviewMythicPlusLevel, SanitizeMythicPlusKeyLevel(mythicPlusKeyLevel))
    end

    local lootCount = type(EJ_GetNumLoot) == "function" and (SecureBlizzardCall(EJ_GetNumLoot) or 0) or 0
    for lootIndex = 1, lootCount do
        local itemInfo = SecureBlizzardCall(C_EncounterJournal.GetLootInfoByIndex, lootIndex)
        if type(itemInfo) == "table" and (itemInfo.link or itemInfo.itemID) then
            local itemReference = itemInfo.link or itemInfo.itemID
            local _, _, _, equipLoc = GetItemInfoInstant(itemReference)
            local slotIDs = GetInventorySlotIDsForEquipLocation(equipLoc)
            local itemLevel = GetItemLevel(itemReference)
            local trackLabel, trackID, currentUpgradeLevel, maxUpgradeLevel = GetUpgradeTrackInfo(itemReference)
            local encounterName

            if type(EJ_GetEncounterInfo) == "function" and type(itemInfo.encounterID) == "number" then
                encounterName = SecureBlizzardCall(EJ_GetEncounterInfo, itemInfo.encounterID)
            end

            if not itemInfo.link and type(itemInfo.itemID) == "number" and type(C_Item) == "table" and type(C_Item.RequestLoadItemDataByID) == "function" then
                C_Item.RequestLoadItemDataByID(itemInfo.itemID)
                canCache = false
            end
            if not itemLevel then
                canCache = false
            end

            table.insert(items, {
                itemID = itemInfo.itemID,
                itemLink = itemInfo.link,
                name = itemInfo.name,
                icon = itemInfo.icon,
                slotText = itemInfo.slot,
                armorType = itemInfo.armorType,
                encounterID = itemInfo.encounterID,
                encounterName = encounterName,
                equipLoc = equipLoc,
                slotIDs = slotIDs,
                itemLevel = itemLevel,
                upgradeTrack = trackLabel,
                upgradeTrackID = trackID,
                currentUpgradeLevel = currentUpgradeLevel,
                maxUpgradeLevel = maxUpgradeLevel,
            })
        end
    end

    RestoreEncounterJournalState(previousState)

    if canCache then
        dungeonLootCache[cacheKey] = items
    end

    return items
end

local function GetDungeonLootForPlayer(dungeonName, selectedDifficulty, mythicPlusKeyLevel)
    local lootItems = BuildDungeonLootItemsForPlayer(dungeonName, selectedDifficulty, mythicPlusKeyLevel)
    local results = {}

    for _, lootItem in ipairs(lootItems) do
        local equippedItems = BuildEquippedItemComparisons(lootItem.slotIDs)
        local isUpgrade = IsLootItemHigherLevelThanEquipped(lootItem.itemLevel, equippedItems)

        table.insert(results, {
            itemID = lootItem.itemID,
            itemLink = lootItem.itemLink,
            name = lootItem.name,
            icon = lootItem.icon,
            slotText = lootItem.slotText,
            armorType = lootItem.armorType,
            encounterID = lootItem.encounterID,
            encounterName = lootItem.encounterName,
            equipLoc = lootItem.equipLoc,
            slotIDs = lootItem.slotIDs,
            itemLevel = lootItem.itemLevel,
            upgradeTrack = lootItem.upgradeTrack,
            upgradeTrackID = lootItem.upgradeTrackID,
            currentUpgradeLevel = lootItem.currentUpgradeLevel,
            maxUpgradeLevel = lootItem.maxUpgradeLevel,
            equippedItems = equippedItems,
            isUpgrade = isUpgrade,
        })
    end

    return results
end

local function DoesDungeonOfferHigherItemLevelLootForPlayer(dungeonName, selectedDifficulty, mythicPlusKeyLevel)
    for _, lootItem in ipairs(GetDungeonLootForPlayer(dungeonName, selectedDifficulty, mythicPlusKeyLevel)) do
        if lootItem.isUpgrade then
            return true
        end
    end

    return false
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
        securecallfunction(C_EncounterJournal.SetPreviewMythicPlusLevel, SanitizeMythicPlusKeyLevel(mythicPlusKeyLevel))
    end

    if type(journalDifficultyID) ~= "number" then
        journalDifficultyID = nil
    end

    securecallfunction(EncounterJournal_OpenJournal, journalDifficultyID, journalInstanceID)
    if type(journalDifficultyID) == "number" then
        securecallfunction(EJ_SetDifficulty, journalDifficultyID)
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
addon.GetDungeonLootForPlayer = GetDungeonLootForPlayer
addon.DoesDungeonOfferHigherItemLevelLootForPlayer = DoesDungeonOfferHigherItemLevelLootForPlayer
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
        RegisterJournalTooltipMoneyWorkaround()
    end
end)
