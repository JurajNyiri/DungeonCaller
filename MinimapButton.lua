local _, addon = ...

addon.MinimapButton = addon.MinimapButton or {}
local MinimapButton = addon.MinimapButton
local Helpers = addon.Helpers

local ADDON_LDB_NAME = "JannetaDungeonCaller"
local ICON_TEXTURE = "Interface\\ICONS\\INV_Misc_Horn_03"
local isInitialized = false

function MinimapButton.Initialize()
    if isInitialized then
        return
    end

    local ldb = LibStub("LibDataBroker-1.1", true)
    local ldbIcon = LibStub("LibDBIcon-1.0", true)

    local db = Helpers.GetGlobalDb()
    db.minimap = {}
    if db.minimap.hide == nil then
        db.minimap.hide = false
    end

    local dataObject = ldb:NewDataObject(ADDON_LDB_NAME, {
        type = "launcher",
        text = "Janneta Dungeon Caller",
        icon = ICON_TEXTURE,
        OnClick = function()
            print("Janneta Dungeon Caller: Minimap button clicked.")
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Janneta Dungeon Caller")
            tooltip:AddLine("Left-click: test action")
            tooltip:AddLine("Drag: move button")
        end,
    })

    ldbIcon:Register(ADDON_LDB_NAME, dataObject, db.minimap)
    isInitialized = true
end
