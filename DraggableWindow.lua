local _, addon = ...

addon.DraggableWindow = addon.DraggableWindow or {}
local DraggableWindow = addon.DraggableWindow
local Helpers = addon.Helpers
local DungeonLists = addon.DungeonLists
local SetDbValue = Helpers.SetDbValue
local Trim = Helpers.Trim

local FRAME_NAME = "DungeonCallerDraggableWindow"
local WINDOW_WIDTH = 360
local WINDOW_HEIGHT = 200
local CONTENT_PADDING = 6
local HEADING_LEFT = 8
local FIRST_GROUP_TOP = -4
local GROUP_HEIGHT = 50
local GROUP_SPACING = -10
local DROPDOWN_LEFT_ADJUSTMENT = -16
local KEY_RIGHT_PADDING = -10
local DROPDOWN_TOP_ADJUSTMENT = -6
local DROPDOWN_MENU_ANCHOR_X = -20
local DROPDOWN_WIDTH = WINDOW_WIDTH - (CONTENT_PADDING*3) + (DROPDOWN_LEFT_ADJUSTMENT * 2)
local BUTTON_WIDTH = WINDOW_WIDTH - (CONTENT_PADDING*3) + (DROPDOWN_LEFT_ADJUSTMENT) +3
local DIFFICULTY_DROPDOWN_FULL_WIDTH = DROPDOWN_WIDTH
local KEY_LEVEL_EDITBOX_WIDTH = 36
local KEY_LEVEL_EDITBOX_HEIGHT = 20
local DIFFICULTY_DROPDOWN_NARROW_WIDTH = DIFFICULTY_DROPDOWN_FULL_WIDTH + DROPDOWN_LEFT_ADJUSTMENT*2 + KEY_RIGHT_PADDING - KEY_LEVEL_EDITBOX_WIDTH - CONTENT_PADDING*2 + 3
local MIN_MPLUS_KEY_LEVEL = 2
local MAX_MPLUS_KEY_LEVEL = 99

local DIFFICULTY_OPTIONS = {
    "Normal",
    "Heroic",
    "Mythic",
    "Mythic+",
}

local LOCKED_OPTION_COLOR_PREFIX = "|cff808080"
local OUT_OF_ROTATION_OPTION_COLOR_PREFIX = "|cff006400"
local OPTION_COLOR_SUFFIX = "|r"

local frame

local function RegisterAsSpecialFrame(frameName)
    if type(UISpecialFrames) ~= "table" then
        return
    end

    for _, registeredFrameName in ipairs(UISpecialFrames) do
        if registeredFrameName == frameName then
            return
        end
    end

    table.insert(UISpecialFrames, frameName)
end

local function GetDifficultyOptions()
    local options = {}
    for _, option in ipairs(DIFFICULTY_OPTIONS) do
        table.insert(options, option)
    end
    return options
end

local function BuildDungeonNameKey(value)
    if type(value) ~= "string" then
        return ""
    end

    return string.lower(Trim(value))
end

local function IsMatchingDifficulty(selectedDifficulty, lockedDifficultyName)
    if type(selectedDifficulty) ~= "string" or selectedDifficulty == "" then
        return false
    end

    if type(lockedDifficultyName) ~= "string" or lockedDifficultyName == "" then
        return false
    end

    return selectedDifficulty == lockedDifficultyName
end

local function CollectLockedDungeonNameLookup()
    local lookup = {}

    local selectedDifficulty = Helpers.GetGlobalDb().selectedDifficulty
    if selectedDifficulty == "Mythic+" then
        return lookup
    end

    for _, entry in ipairs(DungeonLists.CollectLockedDungeonNames() or {}) do
        if type(entry) == "table" then
            local nameKey = BuildDungeonNameKey(entry.name)
            if nameKey ~= "" and IsMatchingDifficulty(selectedDifficulty, entry.difficultyName) then
                lookup[nameKey] = true
            end
        end
    end

    return lookup
end

local function CollectMythicPlusDungeonNameLookup()
    local lookup = {}
    local count = 0

    for _, dungeonName in ipairs(DungeonLists.CollectMythicPlusDungeonNames()) do
        local nameKey = BuildDungeonNameKey(dungeonName)
        if nameKey ~= "" and not lookup[nameKey] then
            lookup[nameKey] = true
            count = count + 1
        end
    end

    return lookup, count
end

local function BuildOptionDisplayContext(group)
    local context = {
        lockedLookup = nil,
        mythicPlusLookup = nil,
        highlightOutOfRotation = false,
    }

    if group.useLockoutHighlight then
        context.lockedLookup = CollectLockedDungeonNameLookup()
    end

    local selectedDifficulty = Helpers.GetGlobalDb().selectedDifficulty
    if group.useMythicOutOfRotationHighlight and selectedDifficulty == "Mythic" then
        local mythicPlusLookup, lookupCount = CollectMythicPlusDungeonNameLookup()
        if lookupCount > 0 then
            context.mythicPlusLookup = mythicPlusLookup
            context.highlightOutOfRotation = true
        end
    end

    return context
end

local function GetOptionDisplayText(option, context)
    local optionName = tostring(option or "")
    local optionKey = BuildDungeonNameKey(optionName)

    local lockedLookup = context and context.lockedLookup
    if optionKey ~= "" and lockedLookup and lockedLookup[optionKey] then
        return LOCKED_OPTION_COLOR_PREFIX .. optionName .. OPTION_COLOR_SUFFIX
    end

    local shouldHighlightOutOfRotation = context and context.highlightOutOfRotation
    local mythicPlusLookup = context and context.mythicPlusLookup
    if optionKey ~= "" and shouldHighlightOutOfRotation and mythicPlusLookup and not mythicPlusLookup[optionKey] then
        return OUT_OF_ROTATION_OPTION_COLOR_PREFIX .. optionName .. OPTION_COLOR_SUFFIX
    end

    return optionName
end

local function SanitizeMythicPlusKeyLevel(value)
    local parsed = tonumber(value)
    if not parsed then
        return MIN_MPLUS_KEY_LEVEL
    end

    parsed = math.floor(parsed)
    if parsed < MIN_MPLUS_KEY_LEVEL then
        return MIN_MPLUS_KEY_LEVEL
    end
    if parsed > MAX_MPLUS_KEY_LEVEL then
        return MAX_MPLUS_KEY_LEVEL
    end
    return parsed
end

local function CollectStringList(provider)
    if type(provider) ~= "function" then
        return {}
    end

    local values = {}
    local seen = {}
    for _, value in ipairs(provider() or {}) do
        if type(value) == "string" and value ~= "" and not seen[value] then
            seen[value] = true
            table.insert(values, value)
        end
    end

    return values
end

local function FindValidSelection(options, currentValue)
    if type(currentValue) == "string" and currentValue ~= "" then
        for _, option in ipairs(options) do
            if option == currentValue then
                return option
            end
        end
    end

    return options[1] or ""
end

local function RefreshDropdownGroup(group)
    group.options = CollectStringList(group.optionProvider)

    local dbValue = Helpers.GetGlobalDb()[group.dbKey]
    local selectedValue = FindValidSelection(group.options, dbValue)
    SetDbValue(group.dbKey, selectedValue)

    if selectedValue ~= "" then
        local selectedText = selectedValue
        if group.useLockoutHighlight or group.useMythicOutOfRotationHighlight then
            selectedText = GetOptionDisplayText(selectedValue, BuildOptionDisplayContext(group))
        end

        UIDropDownMenu_SetSelectedValue(group.dropdown, selectedValue)
        UIDropDownMenu_SetText(group.dropdown, selectedText)
        if type(group.onSelected) == "function" then
            group.onSelected(selectedValue)
        end
        return
    end

    UIDropDownMenu_SetSelectedValue(group.dropdown, nil)
    UIDropDownMenu_SetText(group.dropdown, "No options found")
    if type(group.onSelected) == "function" then
        group.onSelected("")
    end
end

local function CreateDropdownGroup(parent, headingText, dropdownName, dbKey, optionProvider, anchor, yOffset, width, onSelected, useLockoutHighlight)
    local group = CreateFrame("Frame", nil, parent)
    group:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    group:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    group:SetHeight(GROUP_HEIGHT)
    group.dbKey = dbKey
    group.optionProvider = optionProvider
    group.options = {}
    group.onSelected = onSelected
    group.useLockoutHighlight = useLockoutHighlight == true
    group.useMythicOutOfRotationHighlight = false

    local heading = group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", group, "TOPLEFT", HEADING_LEFT, 0)
    heading:SetText(headingText)
    group.heading = heading

    local dropdown = CreateFrame("Frame", dropdownName, group, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", DROPDOWN_LEFT_ADJUSTMENT, DROPDOWN_TOP_ADJUSTMENT)
    group.menuWidth = width or DROPDOWN_WIDTH
    UIDropDownMenu_SetWidth(dropdown, group.menuWidth)
    UIDropDownMenu_SetButtonWidth(dropdown, group.menuWidth)
    UIDropDownMenu_SetText(dropdown, "")
    group.dropdown = dropdown

    local dropdownButton = _G[dropdown:GetName() .. "Button"]
    if dropdownButton then
        UIDropDownMenu_SetAnchor(dropdown, DROPDOWN_MENU_ANCHOR_X, 0, "TOPLEFT", dropdownButton, "BOTTOMLEFT")
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        if #group.options == 0 then
            local emptyInfo = UIDropDownMenu_CreateInfo()
            emptyInfo.text = "No options found"
            emptyInfo.notCheckable = true
            emptyInfo.disabled = true
            emptyInfo.minWidth = group.menuWidth
            UIDropDownMenu_AddButton(emptyInfo, level)
            return
        end

        local optionDisplayContext = BuildOptionDisplayContext(group)

        local selectedValue = Helpers.GetGlobalDb()[group.dbKey]
        for _, option in ipairs(group.options) do
            local info = UIDropDownMenu_CreateInfo()
            local displayText = GetOptionDisplayText(option, optionDisplayContext)
            info.text = displayText
            info.value = option
            info.checked = selectedValue == option
            info.minWidth = group.menuWidth
            info.func = function()
                SetDbValue(group.dbKey, option)
                UIDropDownMenu_SetSelectedValue(group.dropdown, option)
                UIDropDownMenu_SetText(group.dropdown, GetOptionDisplayText(option, optionDisplayContext))
                if type(group.onSelected) == "function" then
                    group.onSelected(option)
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return group
end

local function RefreshDropdownGroups(window)
    if not window.dropdownGroups then
        return
    end

    for _, group in ipairs(window.dropdownGroups) do
        RefreshDropdownGroup(group)
    end
end

local function CreateContentSection(window)
    local parent = window.Inset or window
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_PADDING, -(CONTENT_PADDING + 20))
    section:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    return section
end

local function CreateMythicPlusKeyWidgets(window, parentGroup)
    local keyLevelLabel = parentGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyLevelLabel:SetPoint("LEFT", parentGroup.dropdown, "RIGHT", 0, 2)
    keyLevelLabel:SetText("Key")

    local keyLevelInput = CreateFrame("EditBox", "DungeonCaller_MythicPlusKeyLevelInput", parentGroup, "InputBoxTemplate")
    keyLevelInput:SetPoint("LEFT", keyLevelLabel, "RIGHT", -KEY_RIGHT_PADDING, 0)
    keyLevelInput:SetSize(KEY_LEVEL_EDITBOX_WIDTH, KEY_LEVEL_EDITBOX_HEIGHT)
    keyLevelInput:SetAutoFocus(false)
    keyLevelInput:SetNumeric(true)
    keyLevelInput:SetMaxLetters(2)
    keyLevelInput:SetJustifyH("LEFT")

    local function CommitMythicPlusKeyLevel()
        local sanitizedValue = SanitizeMythicPlusKeyLevel(keyLevelInput:GetText())
        SetDbValue("mythicPlusKeyLevel", sanitizedValue)
        keyLevelInput:SetText(tostring(sanitizedValue))
    end

    keyLevelInput:SetScript("OnEditFocusLost", function()
        CommitMythicPlusKeyLevel()
    end)
    keyLevelInput:SetScript("OnEnterPressed", function(self)
        CommitMythicPlusKeyLevel()
        self:ClearFocus()
    end)
    keyLevelInput:SetScript("OnEscapePressed", function(self)
        local savedValue = SanitizeMythicPlusKeyLevel(Helpers.GetGlobalDb().mythicPlusKeyLevel)
        self:SetText(tostring(savedValue))
        self:ClearFocus()
    end)

    window.mythicPlusKeyWidgets = {
        label = keyLevelLabel,
        input = keyLevelInput,
    }
end

local function UpdateDifficultyDependentWidgets(window, selectedDifficulty)
    local widgets = window.mythicPlusKeyWidgets
    if not widgets then
        return
    end

    local isMythicPlus = selectedDifficulty == "Mythic+"

    if window.dungeonGroup then
        window.dungeonGroup:SetShown(not isMythicPlus)
    end
    if window.mplusGroup then
        window.mplusGroup:SetShown(isMythicPlus)
    end

    local difficultyGroup = window.difficultyGroup
    if difficultyGroup and difficultyGroup.dropdown then
        local width = DIFFICULTY_DROPDOWN_FULL_WIDTH
        if isMythicPlus then
            width = DIFFICULTY_DROPDOWN_NARROW_WIDTH
        end
        difficultyGroup.menuWidth = width
        UIDropDownMenu_SetWidth(difficultyGroup.dropdown, width)
        UIDropDownMenu_SetButtonWidth(difficultyGroup.dropdown, width)
    end

    widgets.label:SetShown(isMythicPlus)
    widgets.input:SetShown(isMythicPlus)

    local savedValue = SanitizeMythicPlusKeyLevel(Helpers.GetGlobalDb().mythicPlusKeyLevel)
    SetDbValue("mythicPlusKeyLevel", savedValue)
    widgets.input:SetText(tostring(savedValue))

    -- Recompute displayed dungeon text markers (gray/normal) for the new difficulty.
    if window.dungeonGroup then
        RefreshDropdownGroup(window.dungeonGroup)
    end
    if window.mplusGroup then
        RefreshDropdownGroup(window.mplusGroup)
    end
end

local function CreateRunDcButton(window, parent, anchor)
    local button = CreateFrame("Button", "DungeonCaller_RunDcButton", parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", HEADING_LEFT, GROUP_SPACING)
    button:SetSize(BUTTON_WIDTH, 24)
    button:SetText("Send")
    button:SetScript("OnClick", function()
        local slashHandler = SlashCmdList and SlashCmdList["DUNGEONCALLER"]
        if type(slashHandler) == "function" then
            slashHandler("")
            return
        end

        print("Dungeon Caller: /dc handler is not available.")
    end)

    window.runDcButton = button
end

local function CreateContentControls(window)
    local section = window.ContentSection

    local rootAnchor = CreateFrame("Frame", nil, section)
    rootAnchor:SetPoint("TOPLEFT", section, "TOPLEFT", 0, FIRST_GROUP_TOP)
    rootAnchor:SetSize(1, 1)

    local difficultyGroup = CreateDropdownGroup(
        section,
        "Difficulty option",
        "DungeonCaller_DifficultyDropdown",
        "selectedDifficulty",
        GetDifficultyOptions,
        rootAnchor,
        0,
        DIFFICULTY_DROPDOWN_FULL_WIDTH,
        function(selectedValue)
            UpdateDifficultyDependentWidgets(window, selectedValue)
        end
    )
    local dungeonGroup = CreateDropdownGroup(
        section,
        "Dungeons option",
        "DungeonCaller_DungeonDropdown",
        "selectedDungeon",
        DungeonLists and DungeonLists.CollectCurrentExpansionDungeonNames,
        difficultyGroup,
        GROUP_SPACING,
        nil,
        nil,
        true
    )
    dungeonGroup.useMythicOutOfRotationHighlight = true
    local mplusGroup = CreateDropdownGroup(
        section,
        "M+ dungeons option",
        "DungeonCaller_MPlusDungeonDropdown",
        "selectedMythicPlusDungeon",
        DungeonLists and DungeonLists.CollectMythicPlusDungeonNames,
        difficultyGroup,
        GROUP_SPACING,
        nil,
        nil,
        true
    )
    CreateMythicPlusKeyWidgets(window, difficultyGroup)

    window.difficultyGroup = difficultyGroup
    window.dungeonGroup = dungeonGroup
    window.mplusGroup = mplusGroup
    CreateRunDcButton(window, section, dungeonGroup)

    window.dropdownGroups = {
        difficultyGroup,
        dungeonGroup,
        mplusGroup,
    }
end

local function CreateWindow()
    local window = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()

    if window.TitleText then
        window.TitleText:SetText("Dungeon Caller")
    end

    window.ContentSection = CreateContentSection(window)
    CreateContentControls(window)
    window:SetScript("OnShow", function(self)
        RefreshDropdownGroups(self)
    end)

    RegisterAsSpecialFrame(FRAME_NAME)

    return window
end

function DraggableWindow.Initialize()
    if frame then
        return frame
    end

    frame = CreateWindow()
    return frame
end

function DraggableWindow.Toggle()
    local window = DraggableWindow.Initialize()
    if window:IsShown() then
        window:Hide()
        return
    end

    window:Show()
end

function DraggableWindow.Show()
    DraggableWindow.Initialize():Show()
end

function DraggableWindow.Hide()
    if frame then
        frame:Hide()
    end
end

function DraggableWindow.GetContentSection()
    return DraggableWindow.Initialize().ContentSection
end
