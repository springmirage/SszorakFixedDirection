local T,C,L=unpack(SszorakFixedDirection)
-- Count the entire roster, including members outside the instance.
local raidSizeWarning=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
T.RaidSizeWarning=raidSizeWarning
raidSizeWarning:SetSize(1100,170)
raidSizeWarning:SetPoint("CENTER",UIParent,"CENTER",0,180)
raidSizeWarning:SetScale(math.min(1,(UIParent:GetWidth()-40)/1100))
raidSizeWarning:SetFrameStrata("FULLSCREEN_DIALOG")
raidSizeWarning:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
raidSizeWarning:SetBackdropColor(.04,0,0,.85)
local raidSizeText=raidSizeWarning:CreateFontString(nil,"OVERLAY")
raidSizeText:SetPoint("CENTER");raidSizeText:SetWidth(1060)
raidSizeText:SetFont(STANDARD_TEXT_FONT,64,"THICKOUTLINE")
raidSizeText:SetTextColor(1,.12,.25)
raidSizeText:SetText("团队成员＞20人，插件将不会工作！")
raidSizeWarning:Hide()
local raidSizeTimer
local function hideRaidSizeWarning()
if raidSizeTimer then raidSizeTimer:Cancel();raidSizeTimer=nil end
raidSizeWarning:Hide()
end
local function checkStartingRaidSize(id,difficulty)
hideRaidSizeWarning()
if id~=3420 or not T.Fixed:IsMythic(difficulty)then return end
if GetNumGroupMembers()<=20 then return end
raidSizeWarning:Show()
raidSizeTimer=C_Timer.NewTimer(5,hideRaidSizeWarning)
end
-- Necessary standalone lifecycle. Legacy M5 modules receive their original events.
local frame=CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED");frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ENCOUNTER_START");frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD");frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent",function(_,event,...)
if event=="ADDON_LOADED"then
if(...)~=T.addonName then return end
SszorakFixedDirectionDB=SszorakFixedDirectionDB or{}
SszorakFixedDirectionDB.modules=SszorakFixedDirectionDB.modules or{}
T:DiagnosticCall("Init")
for _,mod in ipairs(T.modules)do
SszorakFixedDirectionDB.modules[mod.name]=SszorakFixedDirectionDB.modules[mod.name]or{}
mod.db=SszorakFixedDirectionDB.modules[mod.name]
end
for _,mod in ipairs(T.modules)do mod:OnInit()end
elseif event=="PLAYER_LOGIN"then
for _,mod in ipairs(T.modules)do mod:OnLogin()end
elseif event=="ENCOUNTER_START"then
if T.TestHarness.active then T.TestHarness:Stop()end
local id,_,difficulty=...;T.Fixed:Start(id,difficulty)
checkStartingRaidSize(id,difficulty)
elseif event=="ENCOUNTER_END"then
if(...)==3420 then hideRaidSizeWarning();T.Fixed:Stop("ENCOUNTER_END")end
elseif event=="GROUP_ROSTER_UPDATE"then
if raidSizeWarning:IsShown()and GetNumGroupMembers()<=20 then hideRaidSizeWarning()end
elseif event=="PLAYER_ENTERING_WORLD"then
hideRaidSizeWarning()
if T.Fixed.active then T.Fixed:Stop("PLAYER_ENTERING_WORLD")end
elseif event=="PLAYER_LOGOUT"then
hideRaidSizeWarning()
T.Fixed:Stop("PLAYER_LOGOUT");for _,mod in ipairs(T.modules)do mod:OnLogout()end
end
end)
SLASH_SSDFIXEDDIRECTION1="/sfd"
SLASH_SSDFIXEDDIRECTIONSETTINGS1="/m5"
SlashCmdList.SSDFIXEDDIRECTIONSETTINGS=function()
T.Settings:Open()
end
SlashCmdList.SSDFIXEDDIRECTION=function(msg)
local wind=T.moduleMap.WindOctagon
msg=(msg or""):lower()
if msg=="diag status"then T:DiagnosticCall("Status")
elseif msg=="diag clear"then T:DiagnosticCall("Clear")
elseif msg=="teststatus"then T.TestHarness:PrintStatus()
elseif msg=="test"then T.Settings:Open("测试")
elseif msg=="compass"then T.Settings:OpenLegacy(true)
elseif msg=="anchors"then T.Settings:Create();T.Settings:EditText()
elseif msg=="status"then
print("SFD · 周期 "..tostring(T.Fixed.cycle or 0).." · 风向发送 "..tostring(T.Fixed.senderClicks or 0).."/3 · 已接收 "..tostring(T.Fixed.chatReceived or 0))
elseif msg=="stop"then if T.TestHarness.active then T.TestHarness:Stop()else T.Fixed:Stop()end
else T.Settings:Open()end
end
L.windoct_desc="只发送3次风向；囊肿放对面。第4点在BOSS脚下。先面对BOSS，再看罗盘寻找放球位置。"
L.windoct_compass_desc="罗盘上方表示BOSS所在方向。先面对BOSS，再按图走位。"
L.compass_minimap_addon_warning="预览罗盘后，可解锁拖动并调整大小。"
L.windoct_sender_section="发送端（由玩家自行开启）"
L.windoct_sender_warning="发送端每周期只点3次风向；练习请使用“测试发送与接收”。"
L.orbpos_desc="被点名后显示放球提示。前三点按显示的图标放球，第四点前往BOSS脚下。"
