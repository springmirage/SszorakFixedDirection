local T,C,L=unpack(SszorakFixedDirection)
local C_Timer=T.RuntimeClock
local mod=T:NewModule("WindOctagon",L.windoct_name)
local Compass=T.WindOctagonCompass
mod._hideOptions=true
local InCombatLockdown=InCombatLockdown
local RegisterStateDriver=_G.RegisterStateDriver
local UnregisterStateDriver=_G.UnregisterStateDriver
local TARGET_ENC_ID=3420
local ROUND_SIZE=4
local HIDE_AFTER=120
local TEST_HIDE_AFTER=5
local TOKEN_PREFIX="w"
local HEROIC_DIFFICULTY_ID=15
local HEROIC_CLEAR_TIMES={130,270,410}
local DIRS={1,2,3,4,5,6,7,8}
local MARK_KEY={
[1]="windoct_mark_star",
[2]="windoct_mark_circle",[3]="windoct_mark_diamond",[4]="windoct_mark_triangle",
[5]="windoct_mark_moon",
[6]="windoct_mark_square",[7]="windoct_mark_cross",[8]="windoct_mark_skull",
}
local function markName(idx)return L[MARK_KEY[idx]]or("#"..idx)end
mod.DIRS=DIRS
mod.MarkName=markName
local BTN_FRAC={
[5]={0.500,0.102},
[3]={0.781,0.219},
[6]={0.898,0.500},
[7]={0.781,0.781},
[1]={0.500,0.898},
[4]={0.219,0.781},
[2]={0.102,0.500},
[8]={0.219,0.219},
}
local COMPASS_DIRECTION_KEYS={
"windoct_compass_north","windoct_compass_northeast",
"windoct_compass_east","windoct_compass_southeast",
"windoct_compass_south","windoct_compass_southwest",
"windoct_compass_west","windoct_compass_northwest",
}
mod.COMPASS_DIRECTION_KEYS=COMPASS_DIRECTION_KEYS
local PAD=8
local LABELW=60
local ROWH=46
local SLOT=46
local GAPY=4
local ICON=40
local BODYW=SLOT*ROUND_SIZE
local PANEL_W=PAD*2+LABELW+BODYW
local PANEL_H=PAD*2+ROWH*2+GAPY
local SENDER_W=300
local SENDER_H=300
local MEDIA=T.addonPath.."media\\WindOctagon\\"
local ARENA_TEX=MEDIA.."arena.png"
local ESC_SELF="|T"..MEDIA.."%s:"..ICON..":"..ICON.."|t"
local ESC_OPP="|T"..MEDIA.."%s_o:"..ICON..":"..ICON.."|t"
local COMPASS_TARGET_FORMAT="|T"..MEDIA.."%s_o:%d:%d|t"
local COMPASS_MARKER_TEX=MEDIA.."w"
local DEFAULTS={
enabled=true,senderShow=false,senderAnywhere=false,bossOnly=true,
showBall=true,showWind=false,senderAlpha=1.0,
scale=1.0,senderScale=1.0,locked=true,
compassEnabled=true,compassLocked=true,
compassSize=220,compassAlpha=0.9,compassBossAlpha=0.65,
compassMarkerSize=Compass.DEFAULT_MARKER_SIZE,
compassRefreshInterval=Compass.DEFAULT_REFRESH_INTERVAL,
compassShowPlayer=true,
}
local panel
local layers={{},{}}
local senderPanel
local senderSecure
local senderBtns={}
local senderShield
local rowParts={}
local applyRowLayout
local applySenderVisibility
local recvCount=0
local engaged=false
local enabled=false
local combatActive=false
local debugTestOverride=false
local pendingSenderUpdate=false
local senderVisibilityDriver
local dispatcher
local hideTimer
local heroicClearTimers={}
local compassFrame
local compassTargetTimer
local compassLiveTargetActive=false
local compassEncounterActive=false
local compassPreviewing=false
local function cfg(key)
local v=mod.db and mod.db[key]
if v==nil then return DEFAULTS[key]end
return v
end
local function setCfg(key,value)
if mod.db then mod.db[key]=value end
end
local function compassMarkers()
local source=Compass.DEFAULT_MARKERS
local normalized=Compass.NormalizeMarkers(source)
if mod.db then mod.db.compassMarkers=normalized end
return normalized
end
function mod:GetCompassMarkers()
return compassMarkers()
end
local applyCompassVisibility
local function applyCompassLockVisuals()
if not compassFrame then return end
local locked=cfg("compassLocked")~=false
compassFrame:EnableMouse(not locked)
compassFrame.hint:SetShown(not locked)
end
local function applyCompassPosition()
if not compassFrame then return end
local pos=mod.db and mod.db.compassPos
compassFrame:ClearAllPoints()
if type(pos)=="table"then
compassFrame:SetPoint(
pos[1]or"CENTER",UIParent,pos[2]or"CENTER",
tonumber(pos[3])or 0,tonumber(pos[4])or 0)
else
local x,y=Compass.DefaultScreenOffset(UIParent:GetWidth())
compassFrame:SetPoint("CENTER",UIParent,"CENTER",x,y)
end
end
local function applyCompassLayout()
if not compassFrame then return end
local geometry=Compass.Geometry(
cfg("compassSize"),cfg("compassMarkerSize"))
local f=compassFrame
local size=geometry.size
local vertices={}
local angleOffset=Compass.DEFAULT_ANGLE_OFFSET
f:SetSize(size,size)
f:SetAlpha(cfg("compassAlpha")or 0.9)
f.rotationInterval=Compass.NormalizeRefreshInterval(
cfg("compassRefreshInterval"))
for index=1,8 do
local angle=math.rad(
22.5+((index-1)*45)+angleOffset)
vertices[index]={
math.sin(angle)*geometry.outlineRadius,
math.cos(angle)*geometry.outlineRadius,
}
end
for index,edge in ipairs(f.edges)do
local nextIndex=index==8 and 1 or index+1
edge:SetStartPoint(
"CENTER",f,"CENTER",vertices[index][1],vertices[index][2])
edge:SetEndPoint(
"CENTER",f,"CENTER",
vertices[nextIndex][1],vertices[nextIndex][2])
end
for index,axis in ipairs(f.axes)do
local angle=math.rad(((index-1)*45)+angleOffset)
local x=math.sin(angle)*geometry.outlineRadius
local y=math.cos(angle)*geometry.outlineRadius
axis:SetStartPoint("CENTER",f,"CENTER",-x,-y)
axis:SetEndPoint("CENTER",f,"CENTER",x,y)
end
local order=compassMarkers()
local rotationScale=math.sqrt(2)
local layerSize=size*rotationScale
local layerHalf=layerSize*0.5
local markerHalf=geometry.markerSize*rotationScale*0.5
for slot,marker in ipairs(f.markers)do
local angle=math.rad(Compass.MarkerAngle(slot))
local markerX=math.sin(angle)*geometry.markerRadius*rotationScale
local markerY=math.cos(angle)*geometry.markerRadius*rotationScale
marker:SetRotation(0)
marker:SetTexture(
COMPASS_MARKER_TEX..order[slot]..".tga",
"CLAMP","CLAMP")
marker:SetHorizTile(false)
marker:SetVertTile(false)
marker:SetTexCoord(0,1,0,1)
marker:SetSize(layerSize,layerSize)
marker:SetScale(1)
marker:ClearAllPoints()
marker:SetPoint("CENTER",f,"CENTER")
marker:ClearVertexOffsets()
marker:SetVertexOffset(
UPPER_LEFT_VERTEX,
markerX-markerHalf+layerHalf,
markerY+markerHalf-layerHalf)
marker:SetVertexOffset(
LOWER_LEFT_VERTEX,
markerX-markerHalf+layerHalf,
markerY-markerHalf+layerHalf)
marker:SetVertexOffset(
UPPER_RIGHT_VERTEX,
markerX+markerHalf-layerHalf,
markerY+markerHalf-layerHalf)
marker:SetVertexOffset(
LOWER_RIGHT_VERTEX,
markerX+markerHalf-layerHalf,
markerY-markerHalf+layerHalf)
marker:Show()
end
local playerSize=math.max(18,geometry.markerSize*0.85)
f.player:SetSize(playerSize,playerSize)
f.player:SetShown(cfg("compassShowPlayer")~=false)
local targetSize=math.max(28,math.min(40,geometry.markerSize))
f.target:SetSize(targetSize+10,targetSize+10)
f.target:ClearAllPoints()
f.target:SetPoint(
"CENTER",f,"CENTER",geometry.targetX,geometry.targetY)
f.target.icon:SetFont(STANDARD_TEXT_FONT,14,"OUTLINE")
f.target.iconSize=targetSize
applyCompassLockVisuals()
T.Fixed:LayoutCompass(f,geometry)
end
local function createCompass()
if compassFrame then return compassFrame end
local f=CreateFrame(
"Frame","SszorakFixedDirection_WindOctagonCompass",UIParent)
f:SetFrameStrata("DIALOG")
f:SetFrameLevel(180)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:SetClipsChildren(false)
f.axes={}
for index=1,4 do
local axis=f:CreateLine(nil,"BACKGROUND")
axis:SetThickness(1)
axis:SetColorTexture(0.38,0.65,0.76,0.25)
f.axes[index]=axis
end
f.edges={}
for index=1,8 do
local edge=f:CreateLine(nil,"ARTWORK")
edge:SetThickness(2)
edge:SetColorTexture(0.20,0.82,1,0.9)
f.edges[index]=edge
end
f.markers={}
for slot=1,8 do
f.markers[slot]=f:CreateTexture(nil,"OVERLAY")
end
f.player=f:CreateTexture(nil,"OVERLAY",nil,2)
f.player:SetPoint("CENTER")
f.player:SetTexture("Interface\\Minimap\\MinimapArrow")
local target=CreateFrame("Frame",nil,f,"BackdropTemplate")
target:SetFrameLevel(f:GetFrameLevel()+10)
target:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=2,
})
target:SetBackdropColor(0.025,0.015,0.035,0.95)
target:SetBackdropBorderColor(1,0.15,0.5,1)
target.previewIcon=target:CreateTexture(nil,"OVERLAY")
target.previewIcon:SetAllPoints()
target.previewIcon:Hide()
target.icon=target:CreateFontString(nil,"OVERLAY")
target.icon:SetPoint("CENTER")
target.label=target:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
target.label:SetPoint("TOP",target,"BOTTOM",0,-2)
target.label:SetText(L.windoct_compass_target or"Drop")
target.label:SetTextColor(1,0.15,0.5,1)
target:Hide()
f.target=target
local hint=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
hint:SetPoint("TOP",f,"BOTTOM",0,-3)
hint:SetText(L.windoct_compass_drag_hint or"Drag to move")
hint:SetTextColor(0.35,1,0.70,1)
f.hint=hint
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart",function(self)
if cfg("compassLocked")==false then self:StartMoving()end
end)
f:SetScript("OnDragStop",function(self)
self:StopMovingOrSizing()
local point,_,relativePoint,x,y=self:GetPoint()
setCfg("compassPos",{point,relativePoint,x,y})
end)
f:SetScript("OnMouseUp",function(_,button)
if button=="RightButton"and cfg("compassLocked")==false then
mod:SetCompassLocked(true)
end
end)
f:SetScript("OnUpdate",function(self,elapsed)
local h=T.TestHarness
if h and h.active then elapsed=h.status=="RUNNING"and elapsed*h.speed or 0 end
T.Fixed:Animate(self,elapsed)
end)
compassFrame=f
T.Fixed:AttachCompass(f)
applyCompassPosition()
applyCompassLayout()
f:Hide()
return f
end
applyCompassVisibility=function()
local show=Compass.ShouldShow(
cfg("compassEnabled"),
compassEncounterActive,
compassPreviewing)
if show then
local f=createCompass()

f:Show()
elseif compassFrame then
compassFrame:Hide()

end
end
local function renderCompassPreviewTarget(marker)
local f=createCompass()
f.target.icon:SetText("")
f.target.icon:Hide()
f.target.previewIcon:SetTexture(
COMPASS_MARKER_TEX..marker..".tga")
f.target.previewIcon:Show()
f.target.label:SetText(
L.windoct_compass_preview_target or"Preview assignment")
f.target:Show()
end
local function updateCompassPreviewTarget()
if compassLiveTargetActive then return end
if compassPreviewing and cfg("compassEnabled")then
local order=compassMarkers()
renderCompassPreviewTarget(order[1])
elseif compassFrame and compassFrame.target then
compassFrame.target:Hide()
end
end
local function hideCompassTarget()
if compassTargetTimer then
compassTargetTimer:Cancel()
compassTargetTimer=nil
end
compassLiveTargetActive=false
applyCompassVisibility()
updateCompassPreviewTarget()
end
local function showCompassTarget(markerToken,mode,duration)
if not cfg("compassEnabled")then return end
local f=createCompass()
compassLiveTargetActive=true
f.target.previewIcon:Hide()
f.target.icon:Show()
f.target.icon:SetText("")
if mode=="free"then
f.target.icon:SetText(L.windoct_compass_free or"FREE")
else
pcall(function()
f.target.icon:SetFormattedText(
COMPASS_TARGET_FORMAT,
markerToken,f.target.iconSize,f.target.iconSize)
end)
end
f.target.label:SetText(L.windoct_compass_target or"Drop")
f.target:Show()
applyCompassVisibility()
if compassTargetTimer then compassTargetTimer:Cancel()end
compassTargetTimer=C_Timer.NewTimer(
math.max(1,tonumber(duration)or 10),hideCompassTarget)
end
function mod:SetCompassEnabled(value)
setCfg("compassEnabled",value and true or false)
if not value then
compassPreviewing=false
hideCompassTarget()
end
self:ApplyEnabled()
end
function mod:IsCompassEnabled()
return cfg("compassEnabled")==true
end
function mod:SetCompassPreview(value)
compassPreviewing=value and true or false
applyCompassVisibility()
updateCompassPreviewTarget()
if mod.RefreshConfig then mod.RefreshConfig()end
end
function mod:IsCompassPreviewing()
return compassPreviewing
end
function mod:SetCompassLocked(value)
setCfg("compassLocked",value and true or false)
if not value then
compassPreviewing=true
elseif not(
mod._compassConfigWin
and mod._compassConfigWin:IsShown())
then
compassPreviewing=false
end
createCompass()
applyCompassLockVisuals()
applyCompassVisibility()
updateCompassPreviewTarget()
if mod.RefreshConfig then mod.RefreshConfig()end
end
function mod:IsCompassLocked()
return cfg("compassLocked")~=false
end
function mod:SetCompassSize(value)
setCfg("compassSize",Compass.Geometry(value).size)
if compassFrame then applyCompassLayout()end
end
function mod:SetCompassMarkerSize(value)
setCfg(
"compassMarkerSize",
Compass.Geometry(cfg("compassSize"),value).markerSize)
if compassFrame then applyCompassLayout()end
end
function mod:SetCompassAlpha(value)
local alpha=math.max(0.1,math.min(1,tonumber(value)or 0.9))
setCfg("compassAlpha",alpha)
if compassFrame then compassFrame:SetAlpha(alpha)end
end
function mod:SetCompassBossAlpha(value)
setCfg("compassBossAlpha",math.max(0,math.min(1,tonumber(value)or 0.65)))
T.Fixed:RenderBossIcon()
end
function mod:SetCompassRefreshInterval(value)
setCfg(
"compassRefreshInterval",
Compass.NormalizeRefreshInterval(value))
if compassFrame then
compassFrame.rotationInterval=cfg("compassRefreshInterval")
end
end
function mod:SetCompassShowPlayer(value)
setCfg("compassShowPlayer",value and true or false)
if compassFrame then
compassFrame.player:SetShown(cfg("compassShowPlayer"))
end
end
function mod:SetCompassMarker(direction,marker)
if not mod.db then return end
mod.db.compassMarkers=Compass.AssignMarker(
mod.db.compassMarkers,direction,marker)
if compassFrame then applyCompassLayout()end
updateCompassPreviewTarget()
end
function mod:ResetCompassMarkers()
if not mod.db then return end
mod.db.compassMarkers=Compass.NormalizeMarkers(nil)
mod.db.compassMarkerLayoutVersion=Compass.MARKER_LAYOUT_VERSION
if compassFrame then applyCompassLayout()end
updateCompassPreviewTarget()
end
function mod:ResetCompassPosition()
setCfg("compassPos",nil)
applyCompassPosition()
end
local function applyLockVisuals()
if not panel then return end
if cfg("locked")then
panel:SetBackdropBorderColor(0.20,0.40,0.30,0.85)
if panel.hint then panel.hint:Hide()end
else
panel:SetBackdropBorderColor(0.40,1,0.70,1)
if panel.hint then panel.hint:Show()end
end
end
local function createPanel()
if panel then return end
local ROW_LABEL={L.windoct_row_ball,L.windoct_row_wind}
local ROW_BG={{0.16,0.58,0.32,0.95},{0.80,0.80,0.82,0.95}}
local ROW_FG={{1,1,1,1},{0.10,0.12,0.15,1}}
local f=CreateFrame("Frame","SszorakFixedDirection_WindOctPanel",UIParent,"BackdropTemplate")
f:SetSize(PANEL_W,PANEL_H)
f:SetPoint("CENTER",0,190)
f:SetFrameStrata("DIALOG")
f:SetFrameLevel(200)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
f:SetBackdropColor(0.04,0.06,0.05,0.35)
f:SetBackdropBorderColor(0.20,0.40,0.30,0.85)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart",function(self)if not cfg("locked")then self:StartMoving()end end)
f:SetScript("OnDragStop",function(self)
self:StopMovingOrSizing()
local pt,_,rel,x,y=self:GetPoint()
setCfg("panelPos",{pt,rel,x,y})
end)
f:SetScript("OnMouseUp",function(_,button)
if button=="RightButton"and not cfg("locked")then
mod:SetLocked(true)
end
end)
for row=1,2 do
local top=PAD+(row-1)*(ROWH+GAPY)
local parts={seps={}}
rowParts[row]=parts
local lc=f:CreateTexture(nil,"BACKGROUND")
lc:SetPoint("TOPLEFT",f,"TOPLEFT",PAD,-top)
lc:SetSize(LABELW,ROWH)
local bg=ROW_BG[row]
lc:SetColorTexture(bg[1],bg[2],bg[3],bg[4])
parts.lc=lc
local lt=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
lt:SetPoint("CENTER",lc,"CENTER",0,0)
lt:SetText(ROW_LABEL[row]or"")
local fg=ROW_FG[row]
lt:SetTextColor(fg[1],fg[2],fg[3],fg[4])
parts.lt=lt
local body=f:CreateTexture(nil,"BACKGROUND")
body:SetPoint("TOPLEFT",f,"TOPLEFT",PAD+LABELW,-top)
body:SetSize(BODYW,ROWH)
body:SetColorTexture(0.10,0.13,0.18,0.80)
parts.body=body
for k=1,ROUND_SIZE-1 do
local sep=f:CreateTexture(nil,"ARTWORK")
sep:SetColorTexture(0.35,0.42,0.50,0.55)
sep:SetSize(1,ROWH)
sep:SetPoint("TOPLEFT",f,"TOPLEFT",PAD+LABELW+k*SLOT,-top)
parts.seps[k]=sep
end
for k=1,ROUND_SIZE do
local cx=PAD+LABELW+(k-0.5)*SLOT
local cy=top+ROWH/2
local fs=f:CreateFontString(nil,"OVERLAY")
fs:SetFont("Fonts\\FRIZQT__.TTF",15)
fs:SetPoint("CENTER",f,"TOPLEFT",cx,-cy)
fs:Hide()
layers[row][k]=fs
end
end
local hint=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
hint:SetPoint("TOP",f,"BOTTOM",0,-2)
hint:SetTextColor(0.40,1,0.70,1)
hint:SetText(L.windoct_unlock_hint or"可拖动 · 右键锁定")
hint:Hide()
f.hint=hint
local pos=mod.db and mod.db.panelPos
if pos then
f:ClearAllPoints()
f:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])
end
f:SetScale(cfg("scale")or 1.0)
f:Hide()
panel=f
applyRowLayout()
applyLockVisuals()
end
local function rowShown(row)
return(row==1)and(cfg("showBall")~=false)or(row==2 and cfg("showWind")~=false)
end
local function anyRowShown()
return rowShown(1)or rowShown(2)
end
function applyRowLayout()
if not panel then return end
local visible=0
for row=1,2 do
local parts=rowParts[row]
if parts then
local on=rowShown(row)
local top=PAD+visible*(ROWH+GAPY)
if on then visible=visible+1 end
if parts.lc then
parts.lc:ClearAllPoints()
parts.lc:SetPoint("TOPLEFT",panel,"TOPLEFT",PAD,-top)
parts.lc:SetShown(on)
end
if parts.lt then parts.lt:SetShown(on)end
if parts.body then
parts.body:ClearAllPoints()
parts.body:SetPoint("TOPLEFT",panel,"TOPLEFT",PAD+LABELW,-top)
parts.body:SetShown(on)
end
for k,sep in pairs(parts.seps or{})do
sep:ClearAllPoints()
sep:SetPoint("TOPLEFT",panel,"TOPLEFT",PAD+LABELW+k*SLOT,-top)
sep:SetShown(on)
end
for k=1,ROUND_SIZE do
local fs=layers[row][k]
if fs then
local cx=PAD+LABELW+(k-0.5)*SLOT
local cy=top+ROWH/2
fs:ClearAllPoints()
fs:SetPoint("CENTER",panel,"TOPLEFT",cx,-cy)
end
end
end
end
panel:SetHeight(PAD*2+math.max(1,visible)*ROWH
+math.max(0,visible-1)*GAPY)
end
local function stopHideTimer()
if hideTimer then hideTimer:Cancel();hideTimer=nil end
end
local function stopHeroicClearTimers()
for _,timer in ipairs(heroicClearTimers)do
timer:Cancel()
end
heroicClearTimers={}
end
local function clearLayers()
for row=1,2 do
for k=1,ROUND_SIZE do
local fs=layers[row][k]
if fs then fs:Hide()end
end
end
end
local function hideAll()
stopHideTimer()
clearLayers()
recvCount=0
if panel then panel:Hide()end
end
mod._hideAll=hideAll
local function clearGroup()
hideAll()
T:Fire("WIND_OCTAGON_GROUP_CLEARED")
end
local function startHeroicClearTimers()
stopHeroicClearTimers()
for _,clearAt in ipairs(HEROIC_CLEAR_TIMES)do
heroicClearTimers[#heroicClearTimers+1]=C_Timer.NewTimer(clearAt,function()
if engaged then clearGroup()end
end)
end
end
local function startRoundTimer(delay,resetGroup)
if not cfg("locked")then return end
stopHideTimer()
hideTimer=C_Timer.NewTimer(
delay or HIDE_AFTER,resetGroup==false and hideAll or clearGroup)
end
local function renderColumn(seq,msg)
createPanel()
local a,b=layers[1][seq],layers[2][seq]
if not(a and b)then return end
if not anyRowShown()then return end
panel:Show()
pcall(function()
if rowShown(1)then a:SetFormattedText(ESC_OPP,msg);a:Show()else a:Hide()end
if rowShown(2)then b:SetFormattedText(ESC_SELF,msg);b:Show()else b:Hide()end
end)
end
local function onWindMsg(msg)
if not engaged or not T.Fixed.active then return end
if recvCount>=3 then return end
local idx=recvCount
if idx==0 then
clearLayers()
startRoundTimer()
T:Fire("WIND_OCTAGON_ROUND_RESET")
end
recvCount=recvCount+1
local sequence=idx+1
T:Fire("WIND_OCTAGON_MARKER_RECEIVED",sequence,msg)
renderColumn(sequence,msg)
if sequence==3 then T.Fixed:CompleteMarkers()end
applySenderVisibility()
end
function mod:SFDResetCycle()
recvCount=0
-- Reset the three-click adapter, not the legacy assignment group/lifetime timer.
clearLayers()
if panel then panel:Hide()end
applySenderVisibility()
end
function mod:SFDStop()
engaged=false
compassEncounterActive=false
compassPreviewing=false
stopHeroicClearTimers()
hideAll()
hideCompassTarget()
applyCompassVisibility()
end
function mod:SFDUpdateSenderStatus()
if senderPanel and senderPanel.sfdStatus then
senderPanel.sfdStatus:SetText("风向 "..(T.Fixed.senderClicks or 0).."/3"..(T.Fixed.ready and" · 已完成"or""))
end
end
local function activeChannel()
return"RAID"
end
function mod:SendWind(idx)
if T.TestHarness and T.TestHarness.active then return T.TestHarness:SendWind(idx)end
if not idx or not BTN_FRAC[idx]then return end
if not T.Fixed:AllowDirectSend()then return end
if T.Comm and T.Comm.IsSendSuppressed and T.Comm:IsSendSuppressed()then return end
SendChatMessage(TOKEN_PREFIX..idx,activeChannel())
end
local CHAN_SLASH={RAID="/raid",PARTY="/party",SAY="/say"}
local function macroBody(idx)
return(CHAN_SLASH[activeChannel()]or"/raid").." "..TOKEN_PREFIX..idx
end
local function refreshSenderMacrotexts()
if InCombatLockdown()then return false end
for idx,button in pairs(senderBtns)do
button:SetAttribute("macrotext",macroBody(idx))
end
return true
end
local function setSenderFramePoint(frame,pos)
if not frame then return end
frame:ClearAllPoints()
if pos then
frame:SetPoint(pos[1],UIParent,pos[2],pos[3],pos[4])
else
frame:SetPoint("CENTER",UIParent,"CENTER",0,-190)
end
end
local function syncSenderFramePoints(pos)
if InCombatLockdown()then
pendingSenderUpdate=true
return false
end
pos=pos or(mod.db and mod.db.senderPos)
setSenderFramePoint(senderPanel,pos)
setSenderFramePoint(senderSecure,pos)
setSenderFramePoint(senderShield,pos)
return true
end
local function clearSenderVisibilityDriver()
if not(senderSecure and senderVisibilityDriver)then return true end
if InCombatLockdown()then
pendingSenderUpdate=true
return false
end
UnregisterStateDriver(senderSecure,"visibility")
senderVisibilityDriver=nil
return true
end
local function applySenderVisibilityDriver()
if not senderSecure then return false end
if InCombatLockdown()then
pendingSenderUpdate=true
return false
end
local condition=
(cfg("senderAnywhere")or engaged)
and"show"or"[combat] show; hide"
if senderVisibilityDriver==condition then return true end
if senderVisibilityDriver then
UnregisterStateDriver(senderSecure,"visibility")
end
RegisterStateDriver(senderSecure,"visibility",condition)
senderVisibilityDriver=condition
return true
end
local function createSenderPanel()
if senderPanel then return end
if InCombatLockdown()then return end
local f=CreateFrame("Frame","SszorakFixedDirection_WindOctSender",UIParent,"BackdropTemplate")
f:SetSize(SENDER_W,SENDER_H)
f:SetPoint("CENTER",0,-190)
f:SetFrameStrata("MEDIUM")
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetBackdrop({
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
f:SetBackdropBorderColor(0.30,0.50,0.40,0.9)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart",function(self)
if InCombatLockdown()then return end
clearSenderVisibilityDriver()
if senderSecure then senderSecure:Hide()end
if senderShield then senderShield:Hide()end
self:StartMoving()
end)
f:SetScript("OnDragStop",function(self)
self:StopMovingOrSizing()
local pt,_,rel,x,y=self:GetPoint()
local pos={pt,rel,x,y}
setCfg("senderPos",pos)
syncSenderFramePoints(pos)
applySenderVisibilityDriver()
applySenderVisibility()
end)
local base=f:CreateTexture(nil,"BACKGROUND")
base:SetAllPoints(f)
base:SetTexture(ARENA_TEX)
local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("BOTTOM",f,"TOP",0,4)
title:SetText("风向 0/3 · 点击风向，放球在对面")
f.sfdStatus=title
title:SetTextColor(0.55,0.90,0.70,1)
local secure=CreateFrame("Frame","SszorakFixedDirection_WindOctSecure",UIParent)
secure:SetSize(SENDER_W,SENDER_H)
secure:SetPoint("CENTER",UIParent,"CENTER",0,-190)
secure:SetFrameStrata("MEDIUM")
secure:SetFrameLevel((f:GetFrameLevel()or 1)+5)
for _,idx in ipairs(DIRS)do
local fr=BTN_FRAC[idx]
local dx=(fr[1]-0.5)*SENDER_W
local dy=(0.5-fr[2])*SENDER_H
local btn=CreateFrame("Button","SszorakFixedDirection_WindOctBtn"..idx,secure,"SecureActionButtonTemplate")
btn:SetSize(48,48)
btn:SetPoint("CENTER",secure,"CENTER",dx,dy)
btn:RegisterForClicks("AnyUp","AnyDown")
btn:SetAttribute("type","macro")
btn:SetAttribute("macrotext",macroBody(idx))
btn:HookScript("PostClick",function(_,_,down)
if not down then
T.Fixed.senderClicks=math.min(3,(T.Fixed.senderClicks or 0)+1)
mod:SFDUpdateSenderStatus()
applySenderVisibility()
end
end)
local hl=btn:CreateTexture(nil,"HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(0.4,1,0.7,0.30)
local keyLbl=btn:CreateFontString(nil,"OVERLAY")
keyLbl:SetFont(STANDARD_TEXT_FONT,11,"OUTLINE")
keyLbl:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",-1,1)
keyLbl:SetJustifyH("RIGHT")
keyLbl:SetTextColor(1,0.9,0.4,1)
btn.keyLbl=keyLbl
senderBtns[idx]=btn
end
local shield=CreateFrame(
"Frame",
"SszorakFixedDirection_WindOctShield",
UIParent)
shield:SetSize(SENDER_W,SENDER_H)
shield:SetPoint("CENTER",UIParent,"CENTER",0,-190)
shield:SetFrameStrata("HIGH")
shield:SetFrameLevel((f:GetFrameLevel()or 1)+20)
for _,idx in ipairs(DIRS)do
local fr=BTN_FRAC[idx]
local blocker=CreateFrame("Button",nil,shield)
blocker:SetSize(48,48)
blocker:SetPoint(
"CENTER",
shield,
"CENTER",
(fr[1]-0.5)*SENDER_W,
(0.5-fr[2])*SENDER_H)
blocker:SetFrameLevel(shield:GetFrameLevel()+1)
blocker:EnableMouse(true)
blocker:RegisterForClicks("AnyUp","AnyDown")
blocker:SetScript("OnClick",function()end)
end
shield:Hide()
f:Hide()
secure:Hide()
senderPanel=f
senderSecure=secure
senderShield=shield
syncSenderFramePoints()
local scale=cfg("senderScale")or 1.0
f:SetScale(scale)
secure:SetScale(scale)
shield:SetScale(scale)
end
applySenderVisibility=function()
if T.TestHarness and T.TestHarness.active then return end
if not senderPanel then return end
local visible=engaged or cfg("senderAnywhere")
local inCombat=combatActive
local a=visible and(cfg("senderAlpha")or 1.0)or 0
senderPanel:SetAlpha(a)
if senderSecure then senderSecure:SetAlpha(a)end
if not visible and not inCombat and senderSecure then
senderSecure:Hide()
end
senderPanel:EnableMouse(visible)
if senderShield then
senderShield:SetShown((not visible and inCombat)or T.Fixed.ready==true or(T.Fixed.senderClicks or 0)>=3)
end
end
local function applySenderScale()
if not(senderPanel or senderSecure)then return end
if InCombatLockdown()then
pendingSenderUpdate=true
return
end
local s=cfg("senderScale")or 1.0
if senderPanel then senderPanel:SetScale(s)end
if senderSecure then senderSecure:SetScale(s)end
if senderShield then senderShield:SetScale(s)end
end
local function refreshSenderKeys()
if not senderPanel then return end
for _,idx in ipairs(DIRS)do
local b=senderBtns[idx]
if b and b.keyLbl then
local key=GetBindingKey and GetBindingKey("SszorakFixedDirection_WIND_"..idx)
if key and key~=""then
b.keyLbl:SetText((GetBindingText and GetBindingText(key,"KEY_"))or key)
else
b.keyLbl:SetText("")
end
end
end
end
local function clearSenderBindings()
if not InCombatLockdown()and senderSecure and ClearOverrideBindings then
ClearOverrideBindings(senderSecure)
end
end
local function refreshSenderBindings()
if not senderSecure or InCombatLockdown()then return end
if ClearOverrideBindings then ClearOverrideBindings(senderSecure)end
-- Bindings.xml uses the original SendWind hardware entry, with a 3-point gate.
end
function mod:UpdateSenderPanel()
if T.TestHarness and T.TestHarness.active then return end
if InCombatLockdown()then
pendingSenderUpdate=true
return
end
pendingSenderUpdate=false
local show=(enabled or debugTestOverride)
and(cfg("senderShow")or debugTestOverride)
if show then
createSenderPanel()
if senderPanel then
syncSenderFramePoints()
refreshSenderMacrotexts()
refreshSenderKeys()
refreshSenderBindings()
applySenderScale()
senderPanel:Show()
applySenderVisibilityDriver()
applySenderVisibility()
end
elseif senderPanel then
clearSenderBindings()
senderPanel:Hide()
if clearSenderVisibilityDriver()and senderSecure then
senderSecure:Hide()
end
if senderShield then senderShield:Hide()end
end
end
function mod:SetLocked(locked)
setCfg("locked",locked and true or false)
createPanel()
applyLockVisuals()
if not locked then
stopHideTimer()
panel:Show()
elseif not engaged then
panel:Hide()
end
if mod.RefreshConfig then mod.RefreshConfig()end
end
function mod:SetScale(s)
setCfg("scale",s)
if panel then panel:SetScale(s)end
end
function mod:SetRowShown(which,on)
setCfg(which=="wind"and"showWind"or"showBall",on and true or false)
if not panel then return end
applyRowLayout()
if not anyRowShown()then
panel:Hide()
end
end
function mod:SetSenderAnywhere(on)
setCfg("senderAnywhere",on and true or false)
applySenderVisibilityDriver()
applySenderVisibility()
end
function mod:SetSenderAlpha(a)
setCfg("senderAlpha",a)
applySenderVisibility()
end
function mod:SetSenderScale(s)
setCfg("senderScale",s)
applySenderScale()
end
function mod:ResetPanelPos()
setCfg("panelPos",nil)
if panel then
panel:ClearAllPoints()
panel:SetPoint("CENTER",0,190)
end
end
function mod:ShowTest()
createPanel()
clearLayers()
recvCount=0
renderColumn(1,TOKEN_PREFIX..7)
renderColumn(2,TOKEN_PREFIX..8)
renderColumn(3,TOKEN_PREFIX..2)
renderColumn(4,TOKEN_PREFIX..5)
recvCount=ROUND_SIZE
startRoundTimer(TEST_HIDE_AFTER,false)
end
local RECV_EVENTS={
"CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER",
}
local function applyReceiver()
if not dispatcher then return end
for _,ev in ipairs(RECV_EVENTS)do dispatcher:UnregisterEvent(ev)end
if not(enabled or debugTestOverride)then return end
if engaged then
dispatcher:RegisterEvent("CHAT_MSG_RAID")
dispatcher:RegisterEvent("CHAT_MSG_RAID_LEADER")
end
end
local function startEngage()
if engaged then return end
engaged=true
recvCount=0
clearLayers()
applyReceiver()
applySenderVisibility()
mod:UpdateSenderPanel()
applyCompassVisibility()
end
local function stopEngage()
engaged=false
compassEncounterActive=false
stopHeroicClearTimers()
applyReceiver()
hideAll()
hideCompassTarget()
applySenderVisibility()
mod:UpdateSenderPanel()
end
-- Harness bridge: same receiver/UI functions, no global event injection.
function mod:SFDTestBegin()
if not(T.TestHarness and T.TestHarness.active)or InCombatLockdown()then return end
engaged=true;compassEncounterActive=true
createPanel();createSenderPanel()
-- Defence in depth: even a direct /click of a legacy named button cannot
-- send from the out-of-combat harness. In combat the original macro works,
-- while the harness is stopped by PLAYER_REGEN_DISABLED before user input.
for idx,button in pairs(senderBtns)do
button:SetAttribute("macrotext","/stopmacro [nocombat]\n"..macroBody(idx))
end
if senderSecure then senderSecure:Hide()end
if senderShield then senderShield:Hide()end
if dispatcher then for _,ev in ipairs(RECV_EVENTS)do dispatcher:UnregisterEvent(ev)end end
applyCompassVisibility()
T.TestHarness:AttachSender(senderPanel,DIRS,BTN_FRAC,SENDER_W,SENDER_H)
end
function mod:SFDTestReceive(token)
if not(T.TestHarness and T.TestHarness.active)then return end
onWindMsg(token)
end
function mod:SFDTestEnd()
if not InCombatLockdown()then refreshSenderMacrotexts()end
stopEngage()
end
local function ensureDispatcher()
if dispatcher then return end
combatActive=InCombatLockdown()and true or false
dispatcher=CreateFrame("Frame")
dispatcher:SetScript("OnEvent",function(_,e,...)
if e=="ENCOUNTER_START"and T.TestHarness and T.TestHarness.active then T.TestHarness:Stop()end
if T.TestHarness and T.TestHarness.active and(e=="CHAT_MSG_RAID"or e=="CHAT_MSG_RAID_LEADER")then return end
if e=="ENCOUNTER_START"then
combatActive=true
local encounterID,_,difficultyID=...
if encounterID==TARGET_ENC_ID and T.Fixed:IsMythic(difficultyID)then
compassEncounterActive=
Compass.IsSupportedDifficulty(difficultyID)
if cfg("bossOnly")then
startEngage()
else
applyCompassVisibility()
end
if difficultyID==HEROIC_DIFFICULTY_ID then
startHeroicClearTimers()
else
stopHeroicClearTimers()
end
end
elseif e=="ENCOUNTER_END"then
stopEngage()
elseif e=="PLAYER_REGEN_DISABLED"then
combatActive=true
if not cfg("bossOnly")and T.Fixed.active then
startEngage()
else
applySenderVisibility()
end
elseif e=="PLAYER_REGEN_ENABLED"then
combatActive=false
if not cfg("bossOnly")then stopEngage()end
applySenderVisibility()
if pendingSenderUpdate then mod:UpdateSenderPanel()end
if not Compass.ShouldRun(
enabled,cfg("compassEnabled"),debugTestOverride)
then
mod:ApplyEnabled()
end
elseif e=="CHAT_MSG_RAID_LEADER"or e=="CHAT_MSG_PARTY_LEADER"
or e=="CHAT_MSG_RAID"or e=="CHAT_MSG_PARTY"or e=="CHAT_MSG_SAY"then
onWindMsg((...))
elseif e=="PLAYER_ENTERING_WORLD"
or e=="ZONE_CHANGED_NEW_AREA"
then
combatActive=InCombatLockdown()and true or false
if engaged or compassEncounterActive then
stopEngage()
else
mod:UpdateSenderPanel()
end
elseif e=="GROUP_ROSTER_UPDATE"
or e=="PARTY_LEADER_CHANGED"
then
mod:UpdateSenderPanel()
elseif e=="DISPLAY_SIZE_CHANGED"
or e=="UI_SCALE_CHANGED"
then
if compassFrame then
applyCompassPosition()
applyCompassLayout()
end
elseif e=="UPDATE_BINDINGS"then
refreshSenderKeys()
refreshSenderBindings()
end
end)
end
local function setupEvents()
ensureDispatcher()
dispatcher:RegisterEvent("ENCOUNTER_START")
dispatcher:RegisterEvent("ENCOUNTER_END")
dispatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
dispatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
dispatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
dispatcher:RegisterEvent("PARTY_LEADER_CHANGED")
dispatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
dispatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
dispatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
dispatcher:RegisterEvent("UI_SCALE_CHANGED")
dispatcher:RegisterEvent("UPDATE_BINDINGS")
applyReceiver()
end
local function teardownEvents()
if dispatcher then dispatcher:UnregisterAllEvents()end
stopHeroicClearTimers()
hideAll()
hideCompassTarget()
if not InCombatLockdown()then
clearSenderBindings()
if senderSecure then senderSecure:Hide()end
if senderPanel then senderPanel:Hide()end
end
end
function mod:ApplyEnabled()
enabled=cfg("enabled")and true or false
if Compass.ShouldRun(
enabled,cfg("compassEnabled"),debugTestOverride)
then
setupEvents()
self:UpdateSenderPanel()
applyCompassVisibility()
else
teardownEvents()
end
end
function mod:OnInit()
self.db=self.db or{}
self.db.debug=nil
for k,v in pairs(DEFAULTS)do
if self.db[k]==nil then self.db[k]=v end
end
self.db.compassMarkers,self.db.compassMarkerLayoutVersion=
Compass.MigrateMarkers(
self.db.compassMarkers,
self.db.compassMarkerLayoutVersion)
T:On("ORB_POSITION_ALERT_COMPASS_SHOW",showCompassTarget)
T:On("ORB_POSITION_ALERT_COMPASS_HIDE",hideCompassTarget)
end
function mod:OnLogin()
if cfg("compassEnabled")then createCompass()end
self:ApplyEnabled()
end
function mod:OnLogout()
stopHeroicClearTimers()
hideCompassTarget()

end
BINDING_HEADER_SSZORAKFIXEDDIRECTION_WIND="Sszorak Fixed Direction - "..(L.windoct_name or"八方风向")
for _,idx in ipairs(DIRS)do
_G["BINDING_NAME_SszorakFixedDirection_WIND_"..idx]=markName(idx)
end
