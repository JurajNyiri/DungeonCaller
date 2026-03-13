local _, addon = ...

addon.UI = addon.UI or {}
local UI = addon.UI
local Constants = addon.Constants
local Helpers = addon.Helpers

local CHANNEL_OPTIONS = Constants.CHANNEL_OPTIONS
local CLASS_TOKENS = Constants.CLASS_TOKENS
local Trim = Helpers.Trim

local optionsPanel
local optionsInitError
local db

local MAIN_MARGIN_TOP = -16
local MAIN_MARGIN_LEFT = 16
local SECTION_MARGIN_TOP = -6
local CHECKBOX_LABEL_MARGIN_LEFT = 5
local SECTION_WIDTH = 280
local DROPDOWN_MARGIN_LEFT_ADJUSTMENT = -13
local RIGHT_SECTION_MARGIN_LEFT = 40


local function CreateScrollableContent(panel)
    local scrollFrame = CreateFrame("ScrollFrame", "JannetaDungeonCallerOptionsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(488, 1)
    scrollFrame:SetScrollChild(content)

    panel.scrollFrame = scrollFrame
    panel.scrollContent = content
    return content, scrollFrame
end

local function UpdateScrollContentHeight(scrollContent, scrollFrame)
    if not scrollContent or not scrollFrame then
        return
    end

    local top = scrollContent:GetTop()
    if not top then
        return
    end

    local lowest = top
    local children = { scrollContent:GetChildren() }
    for _, child in ipairs(children) do
        if child and child:IsShown() then
            local bottom = child:GetBottom()
            if bottom and bottom < lowest then
                lowest = bottom
            end
        end
    end

    local neededHeight = math.ceil((top - lowest) + 24)
    local visibleHeight = scrollFrame:GetHeight() or 0
    local targetHeight = math.max(neededHeight, visibleHeight, 1)
    scrollContent:SetHeight(targetHeight)
end

local function CurrentDb()
    if type(db) ~= "table" then
        if type(Constants.NewDefaultDb) == "function" then
            db = Constants.NewDefaultDb()
        else
            db = {}
        end
    end
    return db
end

local function SetDbValue(key, value)
    local currentDb = CurrentDb()
    currentDb[key] = value
    if type(JannetaDungeonCallerDB) == "table" then
        JannetaDungeonCallerDB[key] = value
    end
end

local function SetBlClassValue(classToken, enabled)
    local currentDb = CurrentDb()
    if type(currentDb.blClasses) ~= "table" then
        currentDb.blClasses = {}
    end
    currentDb.blClasses[classToken] = enabled

    if type(JannetaDungeonCallerDB) == "table" then
        if type(JannetaDungeonCallerDB.blClasses) ~= "table" then
            JannetaDungeonCallerDB.blClasses = {}
        end
        JannetaDungeonCallerDB.blClasses[classToken] = enabled
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "JannetaDungeonCallerOptionsPanel", UIParent)
    panel.name = "Janneta Dungeon Caller"
    panel:SetWidth(520)
    panel:SetHeight(420)
    return panel
end

local function CreateTitlePanel(panel)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", panel, "TOPLEFT", MAIN_MARGIN_LEFT, MAIN_MARGIN_TOP)
    section:SetSize(488, 40)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    title:SetText("Janneta Dungeon Caller")

    local subtitle = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    subtitle:SetText("UwU")
    section.title = title
    section.subtitle = subtitle

    return section
end

local function CreatePostChannelSection(panel, anchorSection)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, MAIN_MARGIN_TOP)
    section:SetSize(SECTION_WIDTH, 60)

    local channelLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    channelLabel:SetText("Post channel")

    local channelDropdown = CreateFrame("Frame", "JannetaDungeonCaller_ChannelDropdown", section, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", MAIN_MARGIN_TOP, SECTION_MARGIN_TOP)
    UIDropDownMenu_SetWidth(channelDropdown, SECTION_WIDTH+DROPDOWN_MARGIN_LEFT_ADJUSTMENT)
    UIDropDownMenu_SetButtonWidth(channelDropdown, SECTION_WIDTH+DROPDOWN_MARGIN_LEFT_ADJUSTMENT)

    local channelDropdownButton = _G[channelDropdown:GetName() .. "Button"]
    UIDropDownMenu_SetAnchor(channelDropdown, -20, 0, "TOPLEFT", channelDropdownButton, "BOTTOMLEFT")
    UIDropDownMenu_SetText(channelDropdown, "")

    local function GetChannelLabel(value)
        for _, option in ipairs(CHANNEL_OPTIONS) do
            if option.value == value then
                return option.label
            end
        end
        return tostring(value or "")
    end

    local function RefreshChannelDropdown()
        local value = CurrentDb().postChannel
        UIDropDownMenu_SetSelectedValue(channelDropdown, value)
        UIDropDownMenu_SetText(channelDropdown, GetChannelLabel(value))
    end

    UIDropDownMenu_Initialize(channelDropdown, function(_, level)
        if level ~= 1 then
            return
        end

        for _, option in ipairs(CHANNEL_OPTIONS) do
            local channelValue = option.value
            local channelText = option.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = channelText
            info.value = channelValue
            info.checked = CurrentDb().postChannel == channelValue
            info.minWidth = SECTION_WIDTH+DROPDOWN_MARGIN_LEFT_ADJUSTMENT
            info.func = function()
                SetDbValue("postChannel", channelValue)
                RefreshChannelDropdown()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    RefreshChannelDropdown()

    return section
end

local function CreateTextSection(panel, anchorSection, title, valueKey, id)
    local textValue = CurrentDb()[valueKey]
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, 0)
    section:SetSize(SECTION_WIDTH, 50)

    local textLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    textLabel:SetText(title)

    local textInput = CreateFrame("EditBox", id, section, "InputBoxTemplate")
    textInput:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", 5, SECTION_MARGIN_TOP)
    textInput:SetAutoFocus(false)
    textInput:SetWidth(SECTION_WIDTH)
    textInput:SetHeight(24)
    textInput:SetFontObject("GameFontNormal")
    textInput:SetTextColor(1, 1, 1, 1)
    textInput:SetText(textValue or "")
    textInput:HighlightText(0, 0)
    textInput:SetCursorPosition(0)


    local function Commit()
        SetDbValue(valueKey, textInput:GetText() or "")
    end

    textInput:SetScript("OnEditFocusLost", function()
        Commit()
    end)
    textInput:SetScript("OnEscapePressed", function(self)
        self:SetText(textValue or "")
        self:ClearFocus()
    end)
    textInput:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)


    return section
end

local function CreateRoleWordsSection(panel, anchorSection)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", SECTION_WIDTH + RIGHT_SECTION_MARGIN_LEFT, SECTION_MARGIN_TOP)
    section:SetSize(SECTION_WIDTH, 24)

    local roleWordsHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleWordsHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    roleWordsHeader:SetText("Role words")

    local tankSingularSection = CreateTextSection(
        section, section, "Tank singular", "roleTankSingular", "JannetaDungeonCaller_RoleTankSingular"
    )
    local tankPluralSection = CreateTextSection(
        section, tankSingularSection, "Tank plural", "roleTankPlural", "JannetaDungeonCaller_RoleTankPlural"
    )
    local healerSingularSection = CreateTextSection(
        section, tankPluralSection, "Healer singular", "roleHealerSingular", "JannetaDungeonCaller_RoleHealerSingular"
    )
    local healerPluralSection = CreateTextSection(
        section, healerSingularSection, "Healer plural", "roleHealerPlural", "JannetaDungeonCaller_RoleHealerPlural"
    )
    local dpsSingularSection = CreateTextSection(
        section, healerPluralSection, "DPS singular", "roleDpsSingular", "JannetaDungeonCaller_RoleDpsSingular"
    )
    local dpsPluralSection = CreateTextSection(
        section, dpsSingularSection, "DPS plural", "roleDpsPlural", "JannetaDungeonCaller_RoleDpsPlural"
    )
    local readyMessageSection = CreateTextSection(
        section, dpsPluralSection, "Ready message", "readyMessage", "JannetaDungeonCaller_ReadyMessage"
    )
    local needMessageTemplateSection = CreateTextSection(
        section, readyMessageSection, "Need message template", "needMessageTemplate", "JannetaDungeonCaller_NeedMessageTemplate"
    )
    local needBlSuffixSection = CreateTextSection(
        section, needMessageTemplateSection, "Need BL suffix", "needBlSuffix", "JannetaDungeonCaller_NeedBlSuffix"
    )

    return section
end

local function CreateBlRequirementSection(panel, anchorSection)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    section:SetSize(SECTION_WIDTH, 58)

    local blHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    blHeader:SetText("BL Classes rules")

    local blToggle = CreateFrame("CheckButton", "JannetaDungeonCaller_BLRequired", section, "UICheckButtonTemplate")
    blToggle:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", -5, SECTION_MARGIN_TOP)
    blToggle:SetChecked(CurrentDb().requireBl)
    blToggle:SetScript("OnClick", function(self)
        SetDbValue("requireBl", self:GetChecked())
    end)

    local blToggleLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blToggleLabel:SetPoint("LEFT", blToggle, "RIGHT", CHECKBOX_LABEL_MARGIN_LEFT, 0)
    blToggleLabel:SetText("Require BL Class")

    return section
end

local function CreateBlClassesSection(panel, anchorSection)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, 0)
    section:SetSize(SECTION_WIDTH, 200)

    local blClassesHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blClassesHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, SECTION_MARGIN_TOP)
    blClassesHeader:SetText("Classes that have BL")

    local CLASS_COLUMNS = 2
    for index, token in ipairs(CLASS_TOKENS) do
        local row = math.floor((index - 1) / CLASS_COLUMNS)
        local col = (index - 1) % CLASS_COLUMNS

        local cb = CreateFrame("CheckButton", nil, section, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", blClassesHeader, "BOTTOMLEFT", -5 + col * 130, SECTION_MARGIN_TOP - (row * 24))
        cb:SetChecked(CurrentDb().blClasses and CurrentDb().blClasses[token])
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb.text:SetText(LOCALIZED_CLASS_NAMES_MALE[token] or token)
        cb:SetScript("OnClick", function(self)
            SetBlClassValue(token, self:GetChecked())
        end)
    end

    return section
end



local function SetupOptionsPanel()
    local panel = CreateOptionsPanel()
    local scrollContent, scrollFrame = CreateScrollableContent(panel)

    local titleSection = CreateTitlePanel(scrollContent)

    local postChannelSection = CreatePostChannelSection(scrollContent, titleSection)
    local whisperTargetSection = CreateTextSection(
        scrollContent, postChannelSection, "Whisper target", "whisperTarget", "JannetaDungeonCaller_WhisperTarget"
    )

    local blRequirementSection = CreateBlRequirementSection(scrollContent, whisperTargetSection)
    
    local blClassesSection = CreateBlClassesSection(scrollContent, blRequirementSection)

    local roleWordsSection = CreateRoleWordsSection(scrollContent, titleSection)


    panel:SetScript("OnShow", function()
        UpdateScrollContentHeight(scrollContent, scrollFrame)
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end
    end)
    panel:SetScript("OnSizeChanged", function()
        UpdateScrollContentHeight(scrollContent, scrollFrame)
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)

    return panel
end

function UI.SetDb(currentDb)
    db = currentDb
end

function UI.Initialize(currentDb)
    if currentDb then
        db = currentDb
    end
    if optionsPanel then
        return true
    end

    local ok, panelResult = pcall(SetupOptionsPanel)
    if not ok then
        optionsInitError = panelResult
        optionsPanel = nil
        return false
    end

    optionsPanel = panelResult
    optionsInitError = nil
    return true
end

function UI.GetInitError()
    return optionsInitError
end
