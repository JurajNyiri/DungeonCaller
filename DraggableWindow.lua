local _, addon = ...

addon.DraggableWindow = addon.DraggableWindow or {}
local DraggableWindow = addon.DraggableWindow

local FRAME_NAME = "JannetaDungeonCallerDraggableWindow"
local WINDOW_WIDTH = 360
local WINDOW_HEIGHT = 220
local CONTENT_PADDING = 6

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

local function CreateContentSection(window)
    local parent = window.Inset or window
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_PADDING, -(CONTENT_PADDING+20))
    section:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CONTENT_PADDING, CONTENT_PADDING)

    return section
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
        window.TitleText:SetText("Janneta Dungeon Caller")
    end

    window.ContentSection = CreateContentSection(window)

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
