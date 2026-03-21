local _, addon = ...

addon.Helpers = addon.Helpers or {}
local Helpers = addon.Helpers
local Constants = addon.Constants

function Helpers.EnsureDefaults()
    if type(DungeonCallerDB) ~= "table" then
        DungeonCallerDB = {}
    end

    local db = DungeonCallerDB
    local defaults = Constants.NewDefaultDb()
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value
        elseif type(value) == "table" then
            if type(db[key]) ~= "table" then
                db[key] = {}
            end
            for subKey, subValue in pairs(value) do
                if db[key][subKey] == nil then
                    db[key][subKey] = subValue
                end
            end
        end
    end

    return db
end

function Helpers.GetGlobalDb()
    if type(DungeonCallerDB) ~= "table" then
        DungeonCallerDB = Helpers.EnsureDefaults()
    end
    return DungeonCallerDB
end

function Helpers.SetDbValue(key, value)
    local currentDb = Helpers.GetGlobalDb()
    currentDb[key] = value
    if type(DungeonCallerDB) == "table" then
        DungeonCallerDB[key] = value
    end
end

function Helpers.Trim(value)
    value = value or ""
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Helpers.NormalizeNameForLookup(value)
    local normalized = Helpers.Trim(value)
    normalized = string.lower(normalized)
    normalized = normalized:gsub("[%p]", " ")
    normalized = normalized:gsub("%s+", " ")
    return Helpers.Trim(normalized)
end

function Helpers.Pluralize(value, singular, plural)
    if value == 1 then
        return tostring(value) .. " " .. singular
    end
    return tostring(value) .. " " .. plural
end
