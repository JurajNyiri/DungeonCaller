local _, addon = ...

addon.UI = addon.UI or {}
local UI = addon.UI
local Constants = addon.Constants
local Helpers = addon.Helpers
local UIHelpers = addon.UIHelpers
local TemplateEditorUI = addon.TemplateEditorUI

local CHANNEL_OPTIONS = Constants.CHANNEL_OPTIONS
local CLASS_TOKENS = Constants.CLASS_TOKENS
local SetDbValue = Helpers.SetDbValue

local optionsPanel
local optionsRootCategory
local optionsMainCategory
local optionsTemplateCategory
local optionsInitError
local db

local MAIN_MARGIN_TOP = -16
local MAIN_MARGIN_LEFT = 16
local SECTION_MARGIN_TOP = -6
local CHECKBOX_LABEL_MARGIN_LEFT = 5
local SECTION_WIDTH = 280
local RIGHT_SECTION_MARGIN_LEFT = 40
local FULL_SECTION_WIDTH = SECTION_WIDTH * 2 + RIGHT_SECTION_MARGIN_LEFT
local DROPDOWN_MARGIN_LEFT_ADJUSTMENT = -13

local function CreateScrollableContent(panel)
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
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

local function SetBlClassValue(classToken, enabled)
    local currentDb = Helpers.GetGlobalDb()
    if type(currentDb.blClasses) ~= "table" then
        currentDb.blClasses = {}
    end
    currentDb.blClasses[classToken] = enabled

    if type(DungeonCallerDB) == "table" then
        if type(DungeonCallerDB.blClasses) ~= "table" then
            DungeonCallerDB.blClasses = {}
        end
        DungeonCallerDB.blClasses[classToken] = enabled
    end
end

local function CreateOptionsPanel(frameName, panelName)
    local panel = CreateFrame("Frame", frameName, UIParent)
    panel.name = panelName
    panel:SetWidth(520)
    panel:SetHeight(420)
    return panel
end

local function CreateRootOptionsPanel()
    local panel = CreateOptionsPanel("DungeonCallerOptionsPanel", "Dungeon Caller")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", MAIN_MARGIN_LEFT, MAIN_MARGIN_TOP)
    title:SetText("Dungeon Caller")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    subtitle:SetText("Choose 'Main' or 'Template editor' from the left menu.")

    return panel
end

local function CreateTitlePanel(panel, titleText, subtitleText)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", panel, "TOPLEFT", MAIN_MARGIN_LEFT, MAIN_MARGIN_TOP)
    section:SetSize(488, 40)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    title:SetText(titleText or "Dungeon Caller")

    local subtitle = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    subtitle:SetText(subtitleText or "Gather your team effortlessly.")
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

    local channelDropdown = CreateFrame("Frame", "DungeonCaller_ChannelDropdown", section, "UIDropDownMenuTemplate")
    channelDropdown:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", MAIN_MARGIN_TOP, SECTION_MARGIN_TOP)
    UIDropDownMenu_SetWidth(channelDropdown, SECTION_WIDTH + DROPDOWN_MARGIN_LEFT_ADJUSTMENT)
    UIDropDownMenu_SetButtonWidth(channelDropdown, SECTION_WIDTH + DROPDOWN_MARGIN_LEFT_ADJUSTMENT)

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
        local value = Helpers.GetGlobalDb().postChannel
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
            info.checked = Helpers.GetGlobalDb().postChannel == channelValue
            info.minWidth = SECTION_WIDTH + DROPDOWN_MARGIN_LEFT_ADJUSTMENT
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

local function CreateTextSection(panel, anchorSection, title, valueKey, id, width)
    return UIHelpers.CreateBoundTextSection(panel, anchorSection, title, valueKey, id, width, 0, 0)
end

local function CreateBlRequirementSection(panel, anchorSection, xOffset)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", xOffset or 0, SECTION_MARGIN_TOP - 10)
    section:SetSize(SECTION_WIDTH, 58)

    local blHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    blHeader:SetText("BL Classes rules")

    local blToggle = CreateFrame("CheckButton", "DungeonCaller_BLRequired", section, "UICheckButtonTemplate")
    blToggle:SetPoint("TOPLEFT", blHeader, "BOTTOMLEFT", -5, SECTION_MARGIN_TOP)
    blToggle:SetChecked(Helpers.GetGlobalDb().requireBl)
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
    section:SetSize(SECTION_WIDTH, 100)

    local blClassesHeader = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blClassesHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, SECTION_MARGIN_TOP)
    blClassesHeader:SetText("Classes that have BL")

    local classColumns = 2
    for index, token in ipairs(CLASS_TOKENS) do
        local row = math.floor((index - 1) / classColumns)
        local col = (index - 1) % classColumns

        local cb = CreateFrame("CheckButton", nil, section, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", blClassesHeader, "BOTTOMLEFT", -5 + col * 130, SECTION_MARGIN_TOP - (row * 24))
        cb:SetChecked(Helpers.GetGlobalDb().blClasses and Helpers.GetGlobalDb().blClasses[token])
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        cb.text:SetText(LOCALIZED_CLASS_NAMES_MALE[token] or token)
        cb:SetScript("OnClick", function(self)
            SetBlClassValue(token, self:GetChecked())
        end)
    end

    return section
end

local function SetupScrollablePanelBehavior(panel, scrollContent, scrollFrame)
    panel:SetScript("OnShow", function()
        UpdateScrollContentHeight(scrollContent, scrollFrame)
        if scrollFrame then
            scrollFrame:SetVerticalScroll(0)
        end

        if TemplateEditorUI and type(TemplateEditorUI.RefreshTemplateUiState) == "function" then
            TemplateEditorUI.RefreshTemplateUiState()
        end
    end)
    panel:SetScript("OnSizeChanged", function()
        UpdateScrollContentHeight(scrollContent, scrollFrame)
    end)
end

local function BuildMainOptionsPanel(panel)
    local scrollContent, scrollFrame = CreateScrollableContent(panel)

    local titleSection = CreateTitlePanel(scrollContent)
    local postChannelSection = CreatePostChannelSection(scrollContent, titleSection)
    local whisperTargetSection = CreateTextSection(
        scrollContent, postChannelSection, "Whisper target", "whisperTarget", "DungeonCaller_WhisperTarget"
    )

    local rightColumnXOffset = SECTION_WIDTH + RIGHT_SECTION_MARGIN_LEFT
    local blRequirementSection = CreateBlRequirementSection(scrollContent, titleSection, rightColumnXOffset)
    local blClassesSection = CreateBlClassesSection(scrollContent, blRequirementSection)

    local templateAnchor = CreateFrame("Frame", nil, scrollContent)
    templateAnchor:SetSize(1, 1)
    templateAnchor:SetPoint("TOPLEFT", blClassesSection, "BOTTOMLEFT", -rightColumnXOffset, 0)

    TemplateEditorUI.CreateTemplateSection(
        scrollContent,
        templateAnchor,
        FULL_SECTION_WIDTH
    )

    SetupScrollablePanelBehavior(panel, scrollContent, scrollFrame)
end

local function BuildTemplateEditorPanel(panel)
    if not TemplateEditorUI or type(TemplateEditorUI.BuildTemplateEditorPanel) ~= "function" then
        local fallbackTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fallbackTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", MAIN_MARGIN_LEFT, MAIN_MARGIN_TOP)
        fallbackTitle:SetText("Template editor")

        local fallbackText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fallbackText:SetPoint("TOPLEFT", fallbackTitle, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
        fallbackText:SetText("Template editor module failed to load.")
        return
    end

    TemplateEditorUI.BuildTemplateEditorPanel(panel, {
        createScrollableContent = CreateScrollableContent,
        setupScrollablePanelBehavior = SetupScrollablePanelBehavior,
        createTitlePanel = CreateTitlePanel,
        fullSectionWidth = FULL_SECTION_WIDTH,
    })
end

local function SetupOptionsPanel()
    TemplateEditorUI.ResetState()

    local rootPanel = CreateRootOptionsPanel()

    local mainPanel = CreateOptionsPanel("DungeonCallerOptionsMainPanel", "Main")
    BuildMainOptionsPanel(mainPanel)

    local templateEditorPanel = CreateOptionsPanel("DungeonCallerOptionsTemplateEditorPanel", "Template editor")
    BuildTemplateEditorPanel(templateEditorPanel)

    optionsRootCategory = Settings.RegisterCanvasLayoutCategory(rootPanel, rootPanel.name)
    Settings.RegisterAddOnCategory(optionsRootCategory)

    optionsMainCategory = Settings.RegisterCanvasLayoutSubcategory(optionsRootCategory, mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(optionsMainCategory)

    optionsTemplateCategory = Settings.RegisterCanvasLayoutSubcategory(optionsRootCategory, templateEditorPanel, templateEditorPanel.name)
    Settings.RegisterAddOnCategory(optionsTemplateCategory)

    TemplateEditorUI.RefreshTemplateUiState()

    return rootPanel
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

function UI.OpenOptionsPanel()
    local targetCategory = optionsMainCategory or optionsRootCategory
    if not targetCategory then
        return false
    end

    Settings.OpenToCategory(targetCategory:GetID())
    return true
end

function UI.GetInitError()
    return optionsInitError
end
