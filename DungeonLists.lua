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
        local isDungeonSubtype = subtypeID == 1 or subtypeID == 2
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

DungeonLists.CollectCurrentExpansionDungeonNames = CollectCurrentExpansionDungeonNames
DungeonLists.CollectRaidNames = CollectRaidNames
DungeonLists.CollectMythicPlusDungeonNames = CollectMythicPlusDungeonNames
