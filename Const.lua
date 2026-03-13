local _, addon = ...

addon.Constants = addon.Constants or {}
local Constants = addon.Constants

Constants.REQUIRED_TANKS = 1
Constants.REQUIRED_HEALERS = 1
Constants.REQUIRED_DPS = 3

Constants.CLASS_TOKENS = {
    "DEATHKNIGHT",
    "DEMONHUNTER",
    "DRUID",
    "HUNTER",
    "MAGE",
    "MONK",
    "PALADIN",
    "PRIEST",
    "ROGUE",
    "SHAMAN",
    "WARLOCK",
    "WARRIOR",
    "EVOKER",
}

Constants.CHANNEL_OPTIONS = {
    { value = "PARTY", label = "Party" },
    { value = "INSTANCE_CHAT", label = "Instance" },
    { value = "RAID", label = "Raid" },
    { value = "GUILD", label = "Guild" },
    { value = "SAY", label = "Say" },
    { value = "WHISPER", label = "Whisper" },
}

Constants.DEFAULT_BL_CLASSES = {
    MAGE = true,
    SHAMAN = true,
    EVOKER = true,
    HUNTER = true,
}

function Constants.NewDefaultDb()
    local defaults = {
        postChannel = "PARTY",
        whisperTarget = "",
        requireBl = true,
        readyMessage = "Party is ready: 1 tank, 1 healer, 3 DPS.",
        needMessageTemplate = "Need %NEEDED% for %DUNGEON% (%DIFFICULTY%%LEVEL%) %BL%",
        needBlSuffix = "including BL",
        roleTankSingular = "tank",
        roleTankPlural = "tanks",
        roleHealerSingular = "healer",
        roleHealerPlural = "healers",
        roleDpsSingular = "DPS",
        roleDpsPlural = "DPS",
        selectedDungeon = "",
        selectedMythicPlusDungeon = "",
        selectedDifficulty = "Normal",
        mythicPlusKeyLevel = 2,
        blClasses = {},
    }

    for _, classToken in ipairs(Constants.CLASS_TOKENS) do
        defaults.blClasses[classToken] = Constants.DEFAULT_BL_CLASSES[classToken] == true
    end

    return defaults
end
