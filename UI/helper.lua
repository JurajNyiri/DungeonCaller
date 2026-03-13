local _, addon = ...

addon.UIHelpers = addon.UIHelpers or {}
local UIHelpers = addon.UIHelpers
local Helpers = addon.Helpers

local SetDbValue = Helpers.SetDbValue

local SECTION_MARGIN_TOP = -6
local DEFAULT_SECTION_WIDTH = 280

local function CreateBaseTextSection(parent, anchorSection, title, id, width, xOffset, yOffset)
    local sectionWidth = width or DEFAULT_SECTION_WIDTH
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", anchorSection, "BOTTOMLEFT", xOffset or 0, yOffset or 0)
    section:SetSize(sectionWidth, 50)

    local textLabel = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    textLabel:SetText(title)

    local textInput = CreateFrame("EditBox", id, section, "InputBoxTemplate")
    textInput:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", 5, SECTION_MARGIN_TOP)
    textInput:SetAutoFocus(false)
    textInput:SetWidth(sectionWidth)
    textInput:SetHeight(24)
    textInput:SetFontObject("GameFontNormal")
    textInput:SetTextColor(1, 1, 1, 1)

    section.textInput = textInput
    return section, textInput
end

function UIHelpers.SetEditBoxText(editBox, value)
    if not editBox then
        return
    end

    editBox:SetText(value or "")
    editBox:HighlightText(0, 0)
    editBox:SetCursorPosition(0)
end

function UIHelpers.CanUpdateEditBox(editBox)
    if not editBox then
        return false
    end
    if type(editBox.HasFocus) == "function" then
        return not editBox:HasFocus()
    end
    return true
end

function UIHelpers.GetDbStringValue(key)
    local value = Helpers.GetGlobalDb()[key]
    if value == nil then
        return ""
    end
    return tostring(value)
end

function UIHelpers.CreateBoundTextSection(parent, anchorSection, title, valueKey, id, width, xOffset, yOffset)
    local section, textInput = CreateBaseTextSection(parent, anchorSection, title, id, width, xOffset, yOffset)

    local function ReadCurrentValue()
        return UIHelpers.GetDbStringValue(valueKey)
    end

    UIHelpers.SetEditBoxText(textInput, ReadCurrentValue())

    local function Commit()
        SetDbValue(valueKey, textInput:GetText() or "")
    end

    textInput:SetScript("OnEditFocusLost", function()
        Commit()
    end)
    textInput:SetScript("OnEscapePressed", function(self)
        UIHelpers.SetEditBoxText(self, ReadCurrentValue())
        self:ClearFocus()
    end)
    textInput:SetScript("OnEnterPressed", function(self)
        Commit()
        self:ClearFocus()
    end)

    section.Refresh = function()
        UIHelpers.SetEditBoxText(textInput, ReadCurrentValue())
    end

    return section
end

function UIHelpers.CreateStandaloneInputSection(parent, anchorSection, title, id, width, xOffset, yOffset)
    local section, textInput = CreateBaseTextSection(parent, anchorSection, title, id, width, xOffset, yOffset)

    textInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    textInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    return section
end
