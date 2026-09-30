local T,C,L=unpack(SszorakFixedDirection)
local W=T.W
local max,min=math.max,math.min
local mod=T.moduleMap["WindOctagon"]
local Compass=T.WindOctagonCompass
local syncFns={}
local compassSyncFns={}
local function runSync(functions)
for _,fn in ipairs(functions)do pcall(fn)end
end
local function syncAll()runSync(syncFns)end
local function syncCompass()runSync(compassSyncFns)end
local function orbAlertConfig()
local state={}
T:Fire("ORB_POSITION_ALERT_CONFIG_QUERY",state)
return state
end
local function build()
if mod._configWin then return mod._configWin end
local win=W:BackdropFrame(UIParent,0.06,0.09,0.15,0.97,0.30,0.67,0.78,1)
mod._configWin=win
win:SetSize(680,720)
win:SetPoint("CENTER")
win:SetFrameStrata("DIALOG")
win:SetFrameLevel(200)
win:SetBackdropColor(0.06,0.09,0.15,1)
win:SetClampedToScreen(true)
win:SetScale(math.min(1,(UIParent:GetHeight()-40)/win:GetHeight()))
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart",win.StartMoving)
win:SetScript("OnDragStop",win.StopMovingOrSizing)
win:SetScript("OnHide",function()
local r=mod._reopenFn
mod._reopenFn=nil
if r then pcall(r)end
end)
win:Hide()
local close=CreateFrame("Button",nil,win,"UIPanelCloseButton")
close:SetPoint("TOPRIGHT",2,2)
win.title=win:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
win.title:SetPoint("TOPLEFT",16,-14)
win.title:SetTextColor(1,0.82,0.30,1)
local scrollFrame=CreateFrame("ScrollFrame",nil,win)
scrollFrame:SetPoint("TOPLEFT",8,-40)
scrollFrame:SetPoint("BOTTOMRIGHT",-8,8)
scrollFrame:SetClipsChildren(true)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel",function(self,delta)
local cur=self:GetVerticalScroll()
local maxS=self:GetVerticalScrollRange()
self:SetVerticalScroll(max(0,min(maxS,cur-delta*40)))
end)
local content=CreateFrame("Frame",nil,scrollFrame)
scrollFrame:SetScrollChild(content)
content:SetSize(1,1)
local function syncContentWidth()
local w=scrollFrame:GetWidth()
if w and w>0 then content:SetWidth(w)end
end
syncContentWidth()
scrollFrame:SetScript("OnSizeChanged",syncContentWidth)
win:HookScript("OnShow",syncContentWidth)
local PAD_L,PAD_R=20,20
local ITEM_GAP,AFTER_SECTION,BEFORE_SECTION=24,30,16
local y=-12
local TEXT_W=600
local function addSectionHeader(text)
y=y-BEFORE_SECTION
local sec=W:Section(content,text)
sec:SetPoint("TOPLEFT",PAD_L,y)
sec:SetPoint("TOPRIGHT",-PAD_R,y)
y=y-AFTER_SECTION
end
local function addCheck(label,dbKey,tipKey,onChange)
local ck=W:Check(content,label)
ck:SetSize(360,22)
ck:SetPoint("TOPLEFT",PAD_L,y)
ck:OnChange_(function(_,v)
mod.db[dbKey]=v
if onChange then onChange(v)end
end)
if tipKey and L[tipKey]then ck:Tooltip_(L[tipKey])end
syncFns[#syncFns+1]=function()ck:SetChecked_(mod.db[dbKey])end
y=y-ITEM_GAP
return ck
end
local desc=content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
desc:SetPoint("TOPLEFT",PAD_L,y)
desc:SetWidth(TEXT_W)
desc:SetJustifyH("LEFT")
desc:SetText(L.windoct_desc)
desc:SetTextColor(0.6,0.6,0.65,1)
y=y-((desc:GetStringHeight()or 16)+12)
addSectionHeader(L.windoct_receiver_section or L.windoct_general)
addCheck(L.windoct_receiver_enable or L.enable,"enabled",nil,
function()mod:ApplyEnabled()end)
addCheck(L.windoct_boss_only,"bossOnly","windoct_boss_only_tip",nil)
addSectionHeader(L.windoct_sender_section or L.windoct_sender_title)
local senderWarning=content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
senderWarning:SetPoint("TOPLEFT",PAD_L,y)
senderWarning:SetWidth(TEXT_W)
senderWarning:SetJustifyH("LEFT")
senderWarning:SetWordWrap(true)
senderWarning:SetSpacing(3)
senderWarning:SetText(L.windoct_sender_warning or"")
senderWarning:SetTextColor(1.00,0.68,0.25,1)
local warningH=senderWarning:GetStringHeight()
if not warningH or warningH<16 then warningH=34 end
y=y-warningH-10
local showCk=addCheck(L.windoct_sender_show,"senderShow","windoct_sender_show_tip",
function()mod:UpdateSenderPanel()end)
showCk:SetSize(200,22)
y=y+ITEM_GAP
local anywhereCk=W:Check(content,L.windoct_sender_anywhere)
anywhereCk:SetSize(220,22)
anywhereCk:SetPoint("TOPLEFT",PAD_L+210,y)
anywhereCk:OnChange_(function(_,v)mod:SetSenderAnywhere(v)end)
anywhereCk:Tooltip_(L.windoct_sender_anywhere_tip)
syncFns[#syncFns+1]=function()
anywhereCk:SetChecked_(mod.db.senderAnywhere)
end
y=y-ITEM_GAP
local sndLabel=content:CreateFontString(nil,"OVERLAY","GameFontNormal")
sndLabel:SetPoint("TOPLEFT",PAD_L,y)
sndLabel:SetText(L.windoct_sender_scale)
y=y-20
local senderSlider=W:Slider(content,50,200,5)
senderSlider:SetPoint("TOPLEFT",PAD_L,y)
senderSlider:SetWidth(260)
senderSlider:OnChange_(function(_,val)
if mod._syncing then return end
mod:SetSenderScale(val/100)
end)
if senderSlider.Tooltip_ then senderSlider:Tooltip_(L.windoct_sender_scale_tip)end
syncFns[#syncFns+1]=function()
mod._syncing=true
senderSlider:SetValue_((mod.db.senderScale or 1.0)*100)
mod._syncing=nil
end
y=y-36
local alphaLabel=content:CreateFontString(nil,"OVERLAY","GameFontNormal")
alphaLabel:SetPoint("TOPLEFT",PAD_L,y)
alphaLabel:SetText(L.windoct_sender_alpha)
y=y-20
local alphaSlider=W:Slider(content,10,100,5)
alphaSlider:SetPoint("TOPLEFT",PAD_L,y)
alphaSlider:SetWidth(260)
alphaSlider:OnChange_(function(_,val)
if mod._syncing then return end
mod:SetSenderAlpha(val/100)
end)
if alphaSlider.Tooltip_ then alphaSlider:Tooltip_(L.windoct_sender_alpha_tip)end
syncFns[#syncFns+1]=function()
mod._syncing=true
alphaSlider:SetValue_((mod.db.senderAlpha or 1.0)*100)
mod._syncing=nil
end
y=y-36
addSectionHeader(L.windoct_display)
local rowsLab=content:CreateFontString(nil,"OVERLAY","GameFontNormal")
rowsLab:SetPoint("TOPLEFT",PAD_L,y)
rowsLab:SetText(L.windoct_rows)
y=y-22
local ballCk=W:Check(content,L.windoct_row_ball_show)
ballCk:SetSize(200,22)
ballCk:SetPoint("TOPLEFT",PAD_L,y)
ballCk:OnChange_(function(_,v)mod:SetRowShown("ball",v)end)
ballCk:Tooltip_(L.windoct_rows_tip)
syncFns[#syncFns+1]=function()ballCk:SetChecked_(mod.db.showBall~=false)end
local windCk=W:Check(content,L.windoct_row_wind_show)
windCk:SetSize(200,22)
windCk:SetPoint("TOPLEFT",PAD_L+210,y)
windCk:OnChange_(function(_,v)mod:SetRowShown("wind",v)end)
windCk:Tooltip_(L.windoct_rows_tip)
syncFns[#syncFns+1]=function()windCk:SetChecked_(mod.db.showWind~=false)end
y=y-ITEM_GAP-4
local lockBtn=W:Button(content,L.windoct_lock)
lockBtn:SetSize(120,26)
lockBtn:SetPoint("TOPLEFT",PAD_L,y)
lockBtn:OnClick_(function()
mod:SetLocked(not mod.db.locked)
lockBtn:SetText_(mod.db.locked and L.windoct_unlock or L.windoct_lock)
end)
lockBtn:Tooltip_(L.windoct_lock_tip)
syncFns[#syncFns+1]=function()
lockBtn:SetText_(mod.db.locked and L.windoct_unlock or L.windoct_lock)
end
local resetBtn=W:Button(content,L.windoct_reset_pos)
resetBtn:SetSize(100,26)
resetBtn:SetPoint("LEFT",lockBtn,"RIGHT",10,0)
resetBtn:OnClick_(function()mod:ResetPanelPos()end)
y=y-38
local scLabel=content:CreateFontString(nil,"OVERLAY","GameFontNormal")
scLabel:SetPoint("TOPLEFT",PAD_L,y)
scLabel:SetText(L.windoct_scale)
y=y-20
local scaleSlider=W:Slider(content,50,200,5)
scaleSlider:SetPoint("TOPLEFT",PAD_L,y)
scaleSlider:SetWidth(260)
scaleSlider:OnChange_(function(_,val)
if mod._syncing then return end
mod:SetScale(val/100)
end)
syncFns[#syncFns+1]=function()
mod._syncing=true
scaleSlider:SetValue_((mod.db.scale or 1.0)*100)
mod._syncing=nil
end
y=y-36
addSectionHeader(L.orbpos_name)
local orbDesc=content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
orbDesc:SetPoint("TOPLEFT",PAD_L,y)
orbDesc:SetWidth(TEXT_W)
orbDesc:SetJustifyH("LEFT")
orbDesc:SetWordWrap(true)
orbDesc:SetText(L.orbpos_desc)
orbDesc:SetTextColor(0.6,0.6,0.65,1)
y=y-((orbDesc:GetStringHeight()or 16)+12)
local orbEnable=W:Check(content,L.orbpos_enable)
orbEnable:SetSize(360,22)
orbEnable:SetPoint("TOPLEFT",PAD_L,y)
orbEnable:OnChange_(function(_,value)
T:Fire("ORB_POSITION_ALERT_CONFIG_SET","enabled",value)
end)
syncFns[#syncFns+1]=function()
orbEnable:SetChecked_(orbAlertConfig().enabled==true)
end
y=y-ITEM_GAP
local orbDebug=W:Check(content,L.orbpos_debug)
orbDebug:SetSize(360,22)
orbDebug:SetPoint("TOPLEFT",PAD_L,y)
orbDebug:Tooltip_(L.orbpos_debug_tip)
orbDebug:OnChange_(function(_,value)
T:Fire("ORB_POSITION_ALERT_CONFIG_SET","debug",value)
end)
syncFns[#syncFns+1]=function()
orbDebug:SetChecked_(orbAlertConfig().debug==true)
end
y=y-ITEM_GAP
local testFirst=W:Button(content,L.orbpos_test_first)
testFirst:SetSize(130,26)
testFirst:SetPoint("TOPLEFT",PAD_L,y)
testFirst:OnClick_(function()if T.Settings then T.Settings:TestPoint(1)end end)
local testSecond=W:Button(content,L.orbpos_test_second)
testSecond:SetSize(130,26)
testSecond:SetPoint("LEFT",testFirst,"RIGHT",10,0)
testSecond:OnClick_(function()if T.Settings then T.Settings:TestPoint(2)end end)
local testThird=W:Button(content,L.orbpos_test_third)
testThird:SetSize(130,26)
testThird:SetPoint("LEFT",testSecond,"RIGHT",10,0)
testThird:OnClick_(function()if T.Settings then T.Settings:TestPoint(3)end end)
local testFourth=W:Button(content,L.orbpos_test_fourth)
testFourth:SetSize(130,26)
testFourth:SetPoint("LEFT",testThird,"RIGHT",10,0)
testFourth:OnClick_(function()if T.Settings then T.Settings:TestPoint(4)end end)
y=y-38
addSectionHeader(L.windoct_test_section or L.windoct_test)
local testBtn=W:Button(content,L.windoct_test)
testBtn:SetSize(120,26)
testBtn:SetPoint("TOPLEFT",PAD_L,y)
testBtn:OnClick_(function()mod:ShowTest()end)
y=y-36
addSectionHeader(L.windoct_keybinds)
local RAID_MARK="Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
for _,idx in ipairs(mod.DIRS or{})do
local icon=content:CreateTexture(nil,"ARTWORK")
icon:SetSize(22,22)
icon:SetPoint("TOPLEFT",PAD_L,y)
icon:SetTexture(RAID_MARK..idx)
local lbl=content:CreateFontString(nil,"OVERLAY","GameFontNormal")
lbl:SetPoint("LEFT",icon,"RIGHT",8,0)
lbl:SetText(mod.MarkName and mod.MarkName(idx)or("#"..idx))
local kb=W:KeybindButton(content)
kb:SetSize(150,24)
kb:SetPoint("TOPLEFT",PAD_L+150,y-1)
kb:SetAction_("SszorakFixedDirection_WIND_"..idx)
y=y-30
end
local kbNote=content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
kbNote:SetPoint("TOPLEFT",PAD_L,y-2)
kbNote:SetWidth(TEXT_W)
kbNote:SetJustifyH("LEFT")
kbNote:SetTextColor(0.6,0.6,0.65,1)
kbNote:SetText(L.windoct_keybind_note or"")
y=y-28
content:SetHeight(-y+20)
return win
end
local function buildCompass()
if mod._compassConfigWin then return mod._compassConfigWin end
local win=W:BackdropFrame(
UIParent,0.06,0.09,0.15,0.97,0.30,0.67,0.78,1)
mod._compassConfigWin=win
win:SetSize(680,540)
win:SetPoint("CENTER")
win:SetFrameStrata("DIALOG")
win:SetFrameLevel(200)
win:SetBackdropColor(0.06,0.09,0.15,1)
win:SetClampedToScreen(true)
win:SetScale(math.min(1,(UIParent:GetHeight()-40)/win:GetHeight()))
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart",win.StartMoving)
win:SetScript("OnDragStop",win.StopMovingOrSizing)
win:SetScript("OnHide",function()
mod:SetCompassPreview(false)
if mod.db and mod.db.compassLocked==false then
mod:SetCompassLocked(true)
end
local reopen=mod._compassReopenFn
mod._compassReopenFn=nil
if reopen then pcall(reopen)end
end)
win:Hide()
local close=CreateFrame("Button",nil,win,"UIPanelCloseButton")
close:SetPoint("TOPRIGHT",2,2)
win.title=win:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
win.title:SetPoint("TOPLEFT",16,-14)
win.title:SetTextColor(1,0.82,0.30,1)
local PAD_L=20
local y=-48
local desc=win:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
desc:SetPoint("TOPLEFT",PAD_L,y)
desc:SetWidth(640)
desc:SetJustifyH("LEFT")
desc:SetWordWrap(true)
desc:SetText(L.windoct_compass_desc)
desc:SetTextColor(0.6,0.6,0.65,1)
local descHeight=desc:GetStringHeight()
if not descHeight or descHeight<16 then descHeight=44 end
y=y-descHeight-14
local compatibilityWarning=win:CreateFontString(
nil,"OVERLAY","GameFontNormalSmall")
compatibilityWarning:SetPoint("TOPLEFT",PAD_L,y)
compatibilityWarning:SetWidth(640)
compatibilityWarning:SetJustifyH("LEFT")
compatibilityWarning:SetWordWrap(true)
compatibilityWarning:SetText(L.compass_minimap_addon_warning)
compatibilityWarning:SetTextColor(1,0.55,0.25,1)
local warningHeight=compatibilityWarning:GetStringHeight()
if not warningHeight or warningHeight<16 then warningHeight=28 end
y=y-warningHeight-14
local enable=W:Check(win,L.windoct_compass_enable)
enable:SetSize(360,22)
enable:SetPoint("TOPLEFT",PAD_L,y)
enable:OnChange_(function(_,value)
mod:SetCompassEnabled(value)
end)
compassSyncFns[#compassSyncFns+1]=function()
enable:SetChecked_(mod.db.compassEnabled==true)
end
y=y-34
local lock=W:Button(win,"")
lock:SetSize(150,26)
lock:SetPoint("TOPLEFT",PAD_L,y)
lock:OnClick_(function()
mod:SetCompassLocked(not mod.db.compassLocked)
end)
compassSyncFns[#compassSyncFns+1]=function()
lock:SetText_(
mod.db.compassLocked
and L.windoct_compass_unlock
or L.windoct_compass_lock)
end
local preview=W:Button(win,"")
preview:SetSize(120,26)
preview:SetPoint("LEFT",lock,"RIGHT",10,0)
preview:OnClick_(function()
mod:SetCompassPreview(not mod:IsCompassPreviewing())
end)
compassSyncFns[#compassSyncFns+1]=function()
preview:SetText_(
mod:IsCompassPreviewing()
and(L.bossmod_extra_stop_preview or"Stop")
or(L.bossmod_extra_preview or"Preview"))
end
local reset=W:Button(win,L.windoct_compass_reset)
reset:SetSize(160,26)
reset:SetPoint("LEFT",preview,"RIGHT",10,0)
reset:OnClick_(function()mod:ResetCompassPosition()end)
local resetMarkers=W:Button(
win,L.windoct_compass_reset_markers)
resetMarkers:SetSize(170,26)
resetMarkers:SetPoint("LEFT",reset,"RIGHT",10,0)
resetMarkers:OnClick_(function()
mod:ResetCompassMarkers()
syncCompass()
end)
y=y-46
local sizeLabel=win:CreateFontString(
nil,"OVERLAY","GameFontNormal")
sizeLabel:SetPoint("TOPLEFT",PAD_L,y)
sizeLabel:SetText(L.windoct_compass_size)
local alphaLabel=win:CreateFontString(
nil,"OVERLAY","GameFontNormal")
alphaLabel:SetPoint("TOPLEFT",350,y)
alphaLabel:SetText(L.windoct_compass_alpha)
y=y-22
local size=W:Slider(win,120,400,10)
size:SetPoint("TOPLEFT",PAD_L,y)
size:SetWidth(285)
size:OnChange_(function(_,value)
if mod._syncing then return end
mod:SetCompassSize(value)
end)
compassSyncFns[#compassSyncFns+1]=function()
mod._syncing=true
size:SetValue_(mod.db.compassSize or 220)
mod._syncing=nil
end
local alpha=W:Slider(win,10,100,5)
alpha:SetPoint("TOPLEFT",350,y)
alpha:SetWidth(285)
alpha:OnChange_(function(_,value)
if mod._syncing then return end
mod:SetCompassAlpha(value/100)
end)
compassSyncFns[#compassSyncFns+1]=function()
mod._syncing=true
alpha:SetValue_((mod.db.compassAlpha or 0.9)*100)
mod._syncing=nil
end
y=y-50
local markerSizeLabel=win:CreateFontString(
nil,"OVERLAY","GameFontNormal")
markerSizeLabel:SetPoint("TOPLEFT",PAD_L,y)
markerSizeLabel:SetText(L.windoct_compass_marker_size)
local bossAlphaLabel=win:CreateFontString(nil,"OVERLAY","GameFontNormal")
bossAlphaLabel:SetPoint("TOPLEFT",350,y)
bossAlphaLabel:SetText("BOSS图标透明度（0为隐藏）")
y=y-22
local markerSize=W:Slider(win,16,80,1)
markerSize:SetPoint("TOPLEFT",PAD_L,y)
markerSize:SetWidth(285)
local bossAlpha=W:Slider(win,0,100,5)
bossAlpha:SetPoint("TOPLEFT",350,y)
bossAlpha:SetWidth(285)
bossAlpha:OnChange_(function(_,value)
if mod._syncing then return end
mod:SetCompassBossAlpha(value/100)
end)
compassSyncFns[#compassSyncFns+1]=function()
mod._syncing=true
bossAlpha:SetValue_((mod.db.compassBossAlpha or 0.65)*100)
mod._syncing=nil
end
markerSize:OnChange_(function(_,value)
if mod._syncing then return end
mod:SetCompassMarkerSize(value)
end)
compassSyncFns[#compassSyncFns+1]=function()
mod._syncing=true
markerSize:SetValue_(
mod.db.compassMarkerSize or Compass.DEFAULT_MARKER_SIZE)
mod._syncing=nil
end
y=y-50
local positionsLabel=win:CreateFontString(
nil,"OVERLAY","GameFontNormal")
positionsLabel:SetPoint("TOPLEFT",PAD_L,y)
positionsLabel:SetText(L.windoct_compass_positions)
y=y-28
positionsLabel:SetText("月亮与星星位于相对两端；罗盘上方始终表示BOSS所在方向。")
return win
end
function mod.OpenConfig(displayLabel,reopenFn)
local win=build()
mod._reopenFn=reopenFn
win.title:SetText(displayLabel or L.windoct_name)
syncAll()
win:Show()
win:Raise()
end
function mod.OpenCompassConfig(displayLabel,reopenFn)
local win=buildCompass()
mod._compassReopenFn=reopenFn
win.title:SetText(displayLabel or L.windoct_compass_section)
mod:SetCompassPreview(true)
syncCompass()
win:Show()
win:Raise()
end
function mod.RefreshConfig()
if mod._configWin and mod._configWin:IsShown()then syncAll()end
if mod._compassConfigWin and mod._compassConfigWin:IsShown()then
syncCompass()
end
end
function mod.CloseConfig()
if mod._configWin then mod._configWin:Hide()end
end
function mod.CloseCompassConfig()
if mod._compassConfigWin then mod._compassConfigWin:Hide()end
end
