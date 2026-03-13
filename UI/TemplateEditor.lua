local _, addon = ...

addon.TemplateEditorUI = addon.TemplateEditorUI or {}
local TemplateEditorUI = addon.TemplateEditorUI
local Helpers = addon.Helpers
local UIHelpers = addon.UIHelpers

local Trim = Helpers.Trim
local SetDbValue = Helpers.SetDbValue

local SECTION_MARGIN_TOP = -6
local SECTION_WIDTH = 280
local RIGHT_SECTION_MARGIN_LEFT = 40
local FULL_SECTION_WIDTH = SECTION_WIDTH * 2 + RIGHT_SECTION_MARGIN_LEFT
local DROPDOWN_MARGIN_LEFT_ADJUSTMENT = -13

local TEMPLATE_ROLE_FIELDS = {
    { key = "roleTankSingular", label = "Tank singular", inputId = "DungeonCaller_TemplateRoleTankSingular" },
    { key = "roleTankPlural", label = "Tank plural", inputId = "DungeonCaller_TemplateRoleTankPlural" },
    { key = "roleHealerSingular", label = "Healer singular", inputId = "DungeonCaller_TemplateRoleHealerSingular" },
    { key = "roleHealerPlural", label = "Healer plural", inputId = "DungeonCaller_TemplateRoleHealerPlural" },
    { key = "roleDpsSingular", label = "DPS singular", inputId = "DungeonCaller_TemplateRoleDpsSingular" },
    { key = "roleDpsPlural", label = "DPS plural", inputId = "DungeonCaller_TemplateRoleDpsPlural" },
    { key = "readyMessage", label = "Ready message", inputId = "DungeonCaller_TemplateReadyMessage" },
    { key = "needBlSuffix", label = "Need BL suffix", inputId = "DungeonCaller_TemplateNeedBlSuffix" },
}

local state = {
    dropdowns = {},
    mainMessageInput = nil,
    editorNameInput = nil,
    editorMessageInput = nil,
    roleInputs = {},
}

local function PrintTemplateEditorFeedback(message)
    print("Dungeon Caller: " .. tostring(message or ""))
end

local function CollectRoleFieldValuesFromInputs()
    local values = {}
    for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
        local input = state.roleInputs[field.key]
        if input and type(input.GetText) == "function" then
            values[field.key] = tostring(input:GetText() or "")
        else
            values[field.key] = UIHelpers.GetDbStringValue(field.key)
        end
    end

    return values
end

local function EnsureTemplateStorage()
    local currentDb = Helpers.GetGlobalDb()
    if type(currentDb.savedTemplates) ~= "table" then
        SetDbValue("savedTemplates", {})
    end
    if type(currentDb.selectedTemplateName) ~= "string" then
        SetDbValue("selectedTemplateName", "")
    end
end

local function CollectSavedTemplates()
    EnsureTemplateStorage()

    local templates = {}
    local storedTemplates = Helpers.GetGlobalDb().savedTemplates
    if type(storedTemplates) ~= "table" then
        return templates
    end

    for _, entry in ipairs(storedTemplates) do
        if type(entry) == "table" then
            local name = Trim(entry.name or "")
            local text = entry.text
            if name ~= "" and type(text) == "string" and text ~= "" then
                local normalizedEntry = {
                    name = name,
                    text = text,
                }

                for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
                    local roleValue = entry[field.key]
                    if type(roleValue) == "string" then
                        normalizedEntry[field.key] = roleValue
                    end
                end

                table.insert(templates, normalizedEntry)
            end
        end
    end

    return templates
end

local function SetSavedTemplates(templates)
    SetDbValue("savedTemplates", templates or {})
end

local function FindTemplateByName(templateName, templates)
    if type(templateName) ~= "string" or templateName == "" then
        return nil
    end

    local list = templates or CollectSavedTemplates()
    for _, template in ipairs(list) do
        if template.name == templateName then
            return template
        end
    end

    return nil
end

local function RefreshTemplateDropdown(dropdown)
    if not dropdown then
        return
    end

    local templates = CollectSavedTemplates()
    local selectedName = Trim(Helpers.GetGlobalDb().selectedTemplateName or "")
    local selectedTemplate = FindTemplateByName(selectedName, templates)

    if selectedTemplate then
        UIDropDownMenu_SetSelectedValue(dropdown, selectedTemplate.name)
        UIDropDownMenu_SetText(dropdown, selectedTemplate.name)
        return
    end

    UIDropDownMenu_SetSelectedValue(dropdown, nil)
    if #templates == 0 then
        UIDropDownMenu_SetText(dropdown, "No saved templates")
    else
        UIDropDownMenu_SetText(dropdown, "Select a template")
    end
end

local function RefreshAllTemplateDropdowns()
    for _, dropdown in ipairs(state.dropdowns) do
        RefreshTemplateDropdown(dropdown)
    end
end

local function ApplyTemplate(template)
    if type(template) ~= "table" or type(template.name) ~= "string" or type(template.text) ~= "string" then
        return false
    end

    SetDbValue("selectedTemplateName", template.name)
    SetDbValue("needMessageTemplate", template.text)

    for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
        local roleValue = template[field.key]
        if type(roleValue) == "string" then
            SetDbValue(field.key, roleValue)
        end
    end

    UIHelpers.SetEditBoxText(state.mainMessageInput, template.text)
    UIHelpers.SetEditBoxText(state.editorNameInput, template.name)
    UIHelpers.SetEditBoxText(state.editorMessageInput, template.text)

    return true
end

local function RefreshTemplateUiStateInternal()
    RefreshAllTemplateDropdowns()

    local currentTemplateText = Helpers.GetGlobalDb().needMessageTemplate or ""
    if UIHelpers.CanUpdateEditBox(state.mainMessageInput) then
        UIHelpers.SetEditBoxText(state.mainMessageInput, currentTemplateText)
    end

    for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
        local roleInput = state.roleInputs[field.key]
        if UIHelpers.CanUpdateEditBox(roleInput) then
            UIHelpers.SetEditBoxText(roleInput, UIHelpers.GetDbStringValue(field.key))
        end
    end

    local templates = CollectSavedTemplates()
    local selectedName = Trim(Helpers.GetGlobalDb().selectedTemplateName or "")
    local selectedTemplate = FindTemplateByName(selectedName, templates)

    if selectedTemplate then
        if UIHelpers.CanUpdateEditBox(state.editorNameInput) then
            UIHelpers.SetEditBoxText(state.editorNameInput, selectedTemplate.name)
        end
        if UIHelpers.CanUpdateEditBox(state.editorMessageInput) then
            UIHelpers.SetEditBoxText(state.editorMessageInput, selectedTemplate.text)
        end
        return
    end

    if UIHelpers.CanUpdateEditBox(state.editorNameInput) then
        UIHelpers.SetEditBoxText(state.editorNameInput, "")
    end
    if UIHelpers.CanUpdateEditBox(state.editorMessageInput) then
        UIHelpers.SetEditBoxText(state.editorMessageInput, currentTemplateText)
    end
end

local function SaveTemplateFromEditor()
    local nameInput = state.editorNameInput
    local messageInput = state.editorMessageInput
    if not nameInput or not messageInput then
        return
    end

    local templateName = Trim(nameInput:GetText() or "")
    local templateText = Trim(messageInput:GetText() or "")

    if templateName == "" then
        PrintTemplateEditorFeedback("Enter a template name before saving.")
        return
    end
    if templateText == "" then
        PrintTemplateEditorFeedback("Enter a template message before saving.")
        return
    end

    local roleFieldValues = CollectRoleFieldValuesFromInputs()
    for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
        SetDbValue(field.key, roleFieldValues[field.key] or "")
    end

    local templates = CollectSavedTemplates()
    local updated = false
    local templateToApply
    for _, template in ipairs(templates) do
        if template.name == templateName then
            template.text = templateText
            for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
                template[field.key] = roleFieldValues[field.key] or ""
            end
            templateToApply = template
            updated = true
            break
        end
    end

    if not updated then
        templateToApply = {
            name = templateName,
            text = templateText,
        }
        for _, field in ipairs(TEMPLATE_ROLE_FIELDS) do
            templateToApply[field.key] = roleFieldValues[field.key] or ""
        end
        table.insert(templates, templateToApply)
    end

    SetSavedTemplates(templates)
    ApplyTemplate(templateToApply)
    RefreshTemplateUiStateInternal()

    if updated then
        PrintTemplateEditorFeedback("Template updated.")
    else
        PrintTemplateEditorFeedback("Template saved.")
    end
end

local function DeleteTemplateFromEditor()
    local nameInput = state.editorNameInput
    if not nameInput then
        return
    end

    local templateName = Trim(nameInput:GetText() or "")
    if templateName == "" then
        templateName = Trim(Helpers.GetGlobalDb().selectedTemplateName or "")
    end

    if templateName == "" then
        PrintTemplateEditorFeedback("Select or enter a template name to delete.")
        return
    end

    local templates = CollectSavedTemplates()
    local filteredTemplates = {}
    local deleted = false
    for _, template in ipairs(templates) do
        if template.name == templateName then
            deleted = true
        else
            table.insert(filteredTemplates, template)
        end
    end

    if not deleted then
        PrintTemplateEditorFeedback("Template not found: " .. templateName)
        return
    end

    SetSavedTemplates(filteredTemplates)

    if Trim(Helpers.GetGlobalDb().selectedTemplateName or "") == templateName then
        SetDbValue("selectedTemplateName", "")
    end

    UIHelpers.SetEditBoxText(state.editorNameInput, "")
    RefreshTemplateUiStateInternal()
    PrintTemplateEditorFeedback("Template deleted.")
end

local function CreateTemplateDropdownSection(panel, anchorSection, title, dropdownName, width, onSelected)
    local sectionWidth = width or FULL_SECTION_WIDTH
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    section:SetSize(sectionWidth, 60)

    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    label:SetText(title)

    local dropdown = CreateFrame("Frame", dropdownName, section, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, SECTION_MARGIN_TOP)

    local menuWidth = sectionWidth + DROPDOWN_MARGIN_LEFT_ADJUSTMENT
    UIDropDownMenu_SetWidth(dropdown, menuWidth)
    UIDropDownMenu_SetButtonWidth(dropdown, menuWidth)
    UIDropDownMenu_SetText(dropdown, "")

    local dropdownButton = _G[dropdown:GetName() .. "Button"]
    if dropdownButton then
        UIDropDownMenu_SetAnchor(dropdown, -20, 0, "TOPLEFT", dropdownButton, "BOTTOMLEFT")
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local templates = CollectSavedTemplates()
        local selectedTemplateName = Trim(Helpers.GetGlobalDb().selectedTemplateName or "")

        if #templates == 0 then
            local emptyInfo = UIDropDownMenu_CreateInfo()
            emptyInfo.text = "No saved templates"
            emptyInfo.notCheckable = true
            emptyInfo.disabled = true
            emptyInfo.minWidth = menuWidth
            UIDropDownMenu_AddButton(emptyInfo, level)
            return
        end

        for _, template in ipairs(templates) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = template.name
            info.value = template.name
            info.checked = selectedTemplateName == template.name
            info.minWidth = menuWidth
            info.func = function()
                if type(onSelected) == "function" then
                    onSelected(template)
                else
                    ApplyTemplate(template)
                end
                RefreshTemplateUiStateInternal()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    table.insert(state.dropdowns, dropdown)
    RefreshTemplateDropdown(dropdown)

    section.dropdown = dropdown
    return section
end

local function CreateTemplateRoleFieldSection(panel, anchorSection, field, xOffset)
    local section = UIHelpers.CreateBoundTextSection(
        panel,
        anchorSection,
        field.label,
        field.key,
        field.inputId,
        SECTION_WIDTH,
        xOffset or 0,
        0
    )

    state.roleInputs[field.key] = section.textInput
    return section
end

local function CreateTemplateRoleWordsSection(panel, anchorSection)
    local headerSection = CreateFrame("Frame", nil, panel)
    headerSection:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, SECTION_MARGIN_TOP)
    headerSection:SetSize(FULL_SECTION_WIDTH, 24)

    local roleWordsHeader = headerSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleWordsHeader:SetPoint("TOPLEFT", headerSection, "TOPLEFT", 0, 0)
    roleWordsHeader:SetText("Role words")

    local currentAnchor = headerSection
    for index = 1, #TEMPLATE_ROLE_FIELDS, 2 do
        local leftField = TEMPLATE_ROLE_FIELDS[index]
        local rightField = TEMPLATE_ROLE_FIELDS[index + 1]

        local leftSection = CreateTemplateRoleFieldSection(panel, currentAnchor, leftField, 0)
        if rightField then
            CreateTemplateRoleFieldSection(panel, currentAnchor, rightField, SECTION_WIDTH + RIGHT_SECTION_MARGIN_LEFT)
        end

        currentAnchor = leftSection
    end

    return currentAnchor
end

local function CreateNeedTemplateGuideSection(panel, anchorSection, width)
    local sectionWidth = width or SECTION_WIDTH
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, 0)
    section:SetSize(sectionWidth, 1)

    local guide = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    guide:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    guide:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    guide:SetJustifyH("LEFT")
    guide:SetJustifyV("TOP")
    guide:SetText(
        "Template tokens:\n\n"
            .. "%NEEDED% - Missing roles.\n"
            .. "%DUNGEON% - Selected dungeon name.\n"
            .. "%DIFFICULTY% - Selected difficulty.\n"
            .. "%LEVEL% - Mythic+ key level (M+ only).\n"
            .. "%BL% - BL suffix when BL is still needed."
    )
    local guideHeight = math.ceil((guide:GetStringHeight() or 0) + 8)
    if guideHeight < 80 then
        guideHeight = 80
    end
    section:SetHeight(guideHeight)

    return section
end

local function CreateStandaloneInputSection(panel, anchorSection, title, id, width)
    return UIHelpers.CreateStandaloneInputSection(panel, anchorSection, title, id, width, 0, 0)
end

local function CreateTemplateEditorActionsSection(panel, anchorSection, width)
    local sectionWidth = width or FULL_SECTION_WIDTH
    local buttonGap = 12
    local buttonWidth = math.floor((sectionWidth - buttonGap/2) / 2)
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, 0)
    section:SetSize(sectionWidth, 30)

    local saveButton = CreateFrame("Button", "DungeonCaller_SaveTemplateButton", section, "UIPanelButtonTemplate")
    saveButton:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    saveButton:SetSize(buttonWidth, 24)
    saveButton:SetText("Save Template")
    saveButton:SetScript("OnClick", function()
        SaveTemplateFromEditor()
    end)

    local deleteButton = CreateFrame("Button", "DungeonCaller_DeleteTemplateButton", section, "UIPanelButtonTemplate")
    deleteButton:SetPoint("LEFT", saveButton, "RIGHT", buttonGap, 0)
    deleteButton:SetSize(buttonWidth, 24)
    deleteButton:SetText("Delete Template")
    deleteButton:SetScript("OnClick", function()
        DeleteTemplateFromEditor()
    end)

    return section
end

function TemplateEditorUI.ResetState()
    EnsureTemplateStorage()

    state.dropdowns = {}
    state.mainMessageInput = nil
    state.editorNameInput = nil
    state.editorMessageInput = nil
    state.roleInputs = {}
end

function TemplateEditorUI.RefreshTemplateUiState()
    RefreshTemplateUiStateInternal()
end

function TemplateEditorUI.CreateTemplateSection(panel, anchorSection, width)
    local sectionWidth = width or FULL_SECTION_WIDTH
    local section = CreateFrame("Frame", nil, panel)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", 0, 0)
    section:SetSize(sectionWidth, 100)

    CreateTemplateDropdownSection(
        section,
        section,
        "Active template",
        "DungeonCaller_MainTemplateDropdown",
        sectionWidth,
        function(template)
            ApplyTemplate(template)
        end
    )

    state.mainMessageInput = nil
    return section
end

function TemplateEditorUI.BuildTemplateEditorPanel(panel, options)
    options = options or {}
    local createScrollableContent = options.createScrollableContent
    local setupScrollablePanelBehavior = options.setupScrollablePanelBehavior
    local createTitlePanel = options.createTitlePanel
    local fullSectionWidth = options.fullSectionWidth or FULL_SECTION_WIDTH

    if type(createScrollableContent) ~= "function" then
        return
    end
    if type(setupScrollablePanelBehavior) ~= "function" then
        return
    end
    if type(createTitlePanel) ~= "function" then
        return
    end
    local scrollContent, scrollFrame = createScrollableContent(panel)

    local titleSection = createTitlePanel(
        scrollContent,
        "Template editor",
        "Save message templates so you can reuse them later."
    )

    local templateSelectorSection = CreateTemplateDropdownSection(
        scrollContent,
        titleSection,
        "Saved templates",
        "DungeonCaller_TemplateEditorDropdown",
        fullSectionWidth,
        function(template)
            ApplyTemplate(template)
        end
    )

    local templateNameSection = CreateStandaloneInputSection(
        scrollContent,
        templateSelectorSection,
        "Template name",
        "DungeonCaller_TemplateNameInput",
        fullSectionWidth
    )

    local templateMessageSection = CreateStandaloneInputSection(
        scrollContent,
        templateNameSection,
        "Template message",
        "DungeonCaller_TemplateMessageInput",
        fullSectionWidth
    )

    local roleWordsSection = CreateTemplateRoleWordsSection(scrollContent, templateMessageSection)
    local guideSection = CreateNeedTemplateGuideSection(scrollContent, roleWordsSection, fullSectionWidth)
    CreateTemplateEditorActionsSection(scrollContent, guideSection, fullSectionWidth)

    state.editorNameInput = templateNameSection.textInput
    state.editorMessageInput = templateMessageSection.textInput
    UIHelpers.SetEditBoxText(state.editorMessageInput, Helpers.GetGlobalDb().needMessageTemplate or "")

    setupScrollablePanelBehavior(panel, scrollContent, scrollFrame)
end
