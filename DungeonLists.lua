local _, addon = ...

addon.DungeonLists = addon.DungeonLists or {}
local DungeonLists = addon.DungeonLists

local function CollectCurrentExpansionDungeonNames()
    local dungeons = {}
    local seen = {}

    local currentExpansion = GetExpansionLevel()

    local function TryAddByDungeonID(lfgDungeonID)
        if not lfgDungeonID then
            return
        end

        local name, typeID, subtypeID, _, _, _, _, _, expansionLevel, _, _, difficulty, maxPlayers, _, _, _, minPlayers, isTimeWalker = GetLFGDungeonInfo(lfgDungeonID)
        if type(name) ~= "string" or name == "" or seen[name] then
            return
        end

        local isDungeonType = typeID == 1 or typeID == 6
        local isDungeonSubtype = subtypeID == 1 -- or subtypeID == 2 -- 2 are old dungeons in rotation
        local isNormalOrHeroic = difficulty == 1 or difficulty == 2 or difficulty == nil
        local isFivePlayer = (maxPlayers == 5) or (minPlayers == 5)
        local matchesExpansion = (currentExpansion == nil) or (expansionLevel == nil) or (expansionLevel == currentExpansion)

        if isDungeonType and isDungeonSubtype and isNormalOrHeroic and isFivePlayer and not isTimeWalker and matchesExpansion then
            seen[name] = true
            table.insert(dungeons, name)
        end
    end

    local order = GetLFDChoiceOrder()
    for _, dungeonID in ipairs(order) do
        TryAddByDungeonID(dungeonID)
    end

    table.sort(dungeons)
    return dungeons
end

local function CollectRaidNames()
    local raids = {}
    local seen = {}

    local currentExpansion = type(GetExpansionLevel) == "function" and GetExpansionLevel() or nil
    local total = GetNumRFDungeons()
    for index = 1, total do
        local dungeonID, name = GetRFDungeonInfo(index)
        if dungeonID and not seen[name] then
            local _, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
            if expansionLevel == currentExpansion then
                seen[name] = true
                table.insert(raids, name)
            end
        end
    end

    table.sort(raids)
    return raids
end

local function CollectMythicPlusDungeonNames()
    local maps = {}

    for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        table.insert(maps, name)
    end

    table.sort(maps)
    return maps
end

local function CollectLockedDungeonNames()
    local lockedDungeons = {}
    local seen = {}

    local total = GetNumSavedInstances()
    for index = 1, total do
        local name, _, _, _, locked, extended, _, isRaid, maxPlayers, difficultyName = GetSavedInstanceInfo(index)
        local hasLockout = locked or extended
        local isDungeon = not isRaid and (maxPlayers == nil or maxPlayers == 5)
        local resolvedDifficultyName = type(difficultyName) == "string" and difficultyName ~= "" and difficultyName or "Unknown"
        local key = tostring(name) .. ":" .. resolvedDifficultyName

        if hasLockout and isDungeon and type(name) == "string" and name ~= "" and not seen[key] then
            seen[key] = true
            table.insert(lockedDungeons, {
                name = name,
                difficultyName = resolvedDifficultyName,
                locked = locked == true,
                extended = extended == true,
            })
        end
    end

    table.sort(lockedDungeons, function(left, right)
        if left.name ~= right.name then
            return left.name < right.name
        end
        if left.difficultyName ~= right.difficultyName then
            return left.difficultyName < right.difficultyName
        end
        return false
    end)

    return lockedDungeons
end

DungeonLists.CollectCurrentExpansionDungeonNames = CollectCurrentExpansionDungeonNames
DungeonLists.CollectRaidNames = CollectRaidNames
DungeonLists.CollectMythicPlusDungeonNames = CollectMythicPlusDungeonNames
DungeonLists.CollectLockedDungeonNames = CollectLockedDungeonNames
