local _, addon = ...

addon.Helpers = addon.Helpers or {}
local Helpers = addon.Helpers
local Constants = addon.Constants

function Helpers.EnsureDefaults()
    if type(JannetaDungeonCallerDB) ~= "table" then
        JannetaDungeonCallerDB = {}
    end

    local db = JannetaDungeonCallerDB
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
    if type(JannetaDungeonCallerDB) ~= "table" then
        JannetaDungeonCallerDB = Helpers.EnsureDefaults()
    end
    return JannetaDungeonCallerDB
end

function Helpers.Trim(value)
    value = value or ""
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Helpers.Pluralize(value, singular, plural)
    if value == 1 then
        return tostring(value) .. " " .. singular
    end
    return tostring(value) .. " " .. plural
end
