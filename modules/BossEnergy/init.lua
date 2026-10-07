local T=unpack(SszorakFixedDirection)
local mod=T:NewModule("BossEnergy","BOSS能量值")
local UNIT="boss1"
function mod:Layout()
local notify=T.moduleMap.Notify
local db=notify and notify.db
local anchor=db and db.anchors and db.anchors.SERPENT_FURY
local style=db and db.channelDefaults and db.channelDefaults.SERPENT_FURY
if not(self.frame and anchor and style)then return end
self.frame:ClearAllPoints()
self.frame:SetPoint(anchor.point,UIParent,anchor.relPoint,anchor.x,anchor.y-60)
self.frame.fs:SetFont(STANDARD_TEXT_FONT,style.size or 30,"THICKOUTLINE")
self.frame.fs:SetJustifyH(style.alignment or"CENTER")
end
function mod:Stop()
self.engaged=false;self.wave=nil
if self.frame then self.frame:Hide()end
end
function mod:Update()
if not self.frame then return end
local harness=T.TestHarness
local testing=harness and harness.active
if not self.engaged or(not testing and(not UnitExists or not UnitExists(UNIT)))then self.frame:Hide();return end
local inWindow=self.wave~=nil
self.frame:SetBackdropColor(.025,.015,.035,inWindow and .78 or 0)
self.frame:SetBackdropBorderColor(1,.15,.5,inWindow and 1 or 0)
-- Keep restricted power opaque: pass it directly to the permitted text sink.
-- No arithmetic, comparison, string formatting or logging of the live value.
local ok=pcall(function()
local serpent=T.moduleMap.SerpentFuryAlert
local value
if testing then
-- Preview values follow logical time, including pause, speed changes and jumps.
-- They are illustrative and never read or replace the live boss power API.
value=T.SoakConfig:PreviewEnergy(harness.elapsed,serpent.WAVES)
else
value=UnitPower(UNIT)
end
local target=self.wave and serpent.TARGET_ENERGY[self.wave]
if type(target)=="number"then
self.frame.fs:SetFormattedText("%d / %d",value,target)
else
self.frame.fs:SetFormattedText("%d",value)
end
end)
if ok then self.frame:Show()else self.frame:Hide()end
end
function mod:OnInit()
local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
self.frame=f;f:SetSize(440,48);f:SetFrameStrata("DIALOG")
f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
f:SetBackdropColor(.025,.015,.035,0);f:SetBackdropBorderColor(1,.15,.5,0)
f.fs=f:CreateFontString(nil,"OVERLAY")
f.fs:SetPoint("CENTER",f,"CENTER",0,0);f.fs:SetWidth(410);f.fs:SetTextColor(1,.15,.5)
self:Layout();self:Stop()
f:RegisterUnitEvent("UNIT_POWER_FREQUENT",UNIT)
f:RegisterUnitEvent("UNIT_POWER_UPDATE",UNIT)
f:RegisterUnitEvent("UNIT_MAXPOWER",UNIT)
f:RegisterUnitEvent("UNIT_DISPLAYPOWER",UNIT)
f:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
f:SetScript("OnEvent",function()self:Update()end)
T:On("BOSS_ENGAGED",function(id,difficulty)
self:Stop()
if id==3420 and T.Fixed:IsMythic(difficulty)then
self.engaged=true;self:Update()
end
end)
T:On("BOSS_DISENGAGED",function()self:Stop()end)
T:On("SFD_TIMELINE_TICK",function(elapsed)
if not self.engaged then return end
local serpent=T.moduleMap.SerpentFuryAlert
local wave
for i,at in ipairs(serpent and serpent.WAVES or{})do
if elapsed>=at-6 and elapsed<at+5 then wave=i;break end
end
if self.wave~=wave or(T.TestHarness and T.TestHarness.active)then self.wave=wave;self:Update()end
end)
-- Follow the existing upper-centre reminder row when its saved position/style changes.
local channel=T.Notify:GetChannel("SERPENT_FURY")
local reposition=channel.Reposition
channel.Reposition=function(...)
reposition(...);self:Layout()
end
channel.UpdateAllSettings=channel.Reposition
end
function mod:OnLogout()self:Stop()end
