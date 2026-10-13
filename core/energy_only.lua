local T = unpack(SszorakFixedDirection)
-- Independent native boss-energy display. Legacy reminder/test modules are not loaded.
T.energyOnlyMode = true
local mod = T:NewModule("BossEnergy", "Boss Energy Only")
local UNIT = "boss1"
local engaged = false
local frame = CreateFrame("Frame", nil, UIParent)
mod.frame = frame
frame:SetSize(440, 48)
frame:SetFrameStrata("DIALOG")
frame.fs = frame:CreateFontString(nil, "OVERLAY")
frame.fs:SetPoint("CENTER", frame, "CENTER", 0, 0)
frame.fs:SetWidth(410)
frame.fs:SetTextColor(1, .15, .5)
frame:Hide()

function mod:Layout()
    local db = SszorakFixedDirectionDB
    local notify = db and db.modules and db.modules.Notify
    local anchor = notify and notify.anchors and notify.anchors.SERPENT_FURY
    local style = notify and notify.channelDefaults and notify.channelDefaults.SERPENT_FURY
    local position = db and db.modules and db.modules.BossEnergy and db.modules.BossEnergy.position
    local point = position and position[1] or anchor and anchor.point or "CENTER"
    local relativePoint = position and position[2] or anchor and anchor.relPoint or "CENTER"
    local x = position and position[3] or anchor and tonumber(anchor.x) or 0
    local y = position and position[4] or (anchor and tonumber(anchor.y) or 180) - 60
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x or 0, y or 120)
    frame.fs:SetFont(STANDARD_TEXT_FONT, style and style.size or 30, "THICKOUTLINE")
    frame.fs:SetJustifyH(style and style.alignment or "CENTER")
end

local function Update()
    if not mod.editing and (not engaged or not UnitExists(UNIT)) then frame:Hide(); return end
    -- Restricted power stays opaque and goes directly to the permitted sink.
    local ok = pcall(function() frame.fs:SetFormattedText("%d", mod.editing and 75 or UnitPower(UNIT)) end)
    if ok then frame:Show() else frame:Hide() end
end

for _, event in ipairs({"UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER"}) do
    frame:RegisterUnitEvent(event, UNIT)
end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_LOGOUT"}) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= T.addonName then return end
        mod:Layout()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        local _, _, difficulty=GetInstanceInfo()
        engaged = UnitExists(UNIT) and T.Fixed:IsMythic(difficulty)
        mod:Layout()
    elseif event == "ENCOUNTER_START" then
        local id, _, difficulty = ...
        engaged = id==3420 and T.Fixed:IsMythic(difficulty)
    elseif event == "ENCOUNTER_END" or event == "PLAYER_LOGOUT" then
        engaged = false
    end
    Update()
end)

frame:SetMovable(true);frame:SetClampedToScreen(true);frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart",function(self)if mod.editing then self:StartMoving()end end)
frame:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    if not mod.editing then return end
    local point,_,relativePoint,x,y=self:GetPoint()
    T:SavePosition("BossEnergy","position",{point,relativePoint,x,y})
end)
function mod:SetPositionEditing(value)
    self.editing=value and true or false;frame:EnableMouse(self.editing)
    self:Layout();Update()
end
frame:EnableMouse(false)
