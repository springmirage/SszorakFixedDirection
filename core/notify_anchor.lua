local T,_,L=unpack(SszorakFixedDirection)
local W=T.W
T.Notify.anchor=T.Notify.anchor or{}
local A=T.Notify.anchor
A._editing=false
A._anchorBars={}
A._demoTickers={}
A._controlPanel=nil
local createSettingsPopup,startDemo,stopDemo
local ANCHOR_HEIGHT=24
local ANCHOR_WIDTH=280
local PANEL_W=360
local PANEL_H=184
local function _splitDemoTexts()
local raw=L and L.notify_anchor_demo_texts
local out={}
if type(raw)=="string"and raw~=""then
for s in raw:gmatch("[^,]+")do
local trimmed=s:match("^%s*(.-)%s*$")
if trimmed and trimmed~=""then out[#out+1]=trimmed end
end
end
if#out==0 then
out={"Tranquility","Divine Shield","Soul Link","Flash Heal",
"Blessing of Sacrifice","Totem","Sanctuary","War Stomp",
"Empower","Resurrection","Soul Hunt","Cleanse",
"Dispel","Raise Dead"}
end
return out
end
local DEMO_TEXTS=_splitDemoTexts()
local DEMO_ICONS={7439201,4630470,135940,135963,135944}
local DEMO_REFRESH=5
local DEMO_DURATION_MIN=6
local DEMO_DURATION_MAX=12
local function getDB()return T.moduleMap["Notify"].db end
local function isVisualChannel(meta)return meta.needsAnchor==true end
local function randomColor()
local hi=math.random(3)
local r=(hi==1 and math.random(70,100)or math.random(30,80))/100
local g=(hi==2 and math.random(70,100)or math.random(30,80))/100
local b=(hi==3 and math.random(70,100)or math.random(30,80))/100
return{r,g,b}
end
local function randomDemoSample(channelID)
local text=DEMO_TEXTS[math.random(#DEMO_TEXTS)]
local icon=DEMO_ICONS[math.random(#DEMO_ICONS)]
local duration=math.random(DEMO_DURATION_MIN,DEMO_DURATION_MAX)
local color=randomColor()
if channelID=="BAR"then
return{text=text,iconID=icon,duration=duration,color=color}
elseif channelID=="HEALTHBAR"then
return{
iconID=icon,
unitValueType=(math.random(2)==1)and"health"or"absorb",
duration=4.5,
previewMax=1000000,
}
elseif channelID=="ICON"then
return{text=text,iconID=icon,duration=duration,color=color}
elseif channelID=="SERPENT_FURY"then
return{text="开关：4",duration=duration,attention=true}
elseif channelID=="TEXT"then
return{text=text,duration=duration,color=color}
elseif channelID=="CIRCLE"then
return{text=text,duration=duration,color=color}
elseif channelID=="TIMELINE"then
return{text=text,iconID=icon,duration=math.random(3,6),color=color}
elseif channelID=="TICKBAR"then
return{text=text,iconID=icon,color=color,ticks={1.2,2.4,3.6}}
end
return{}
end
function A:GetPosition(channelID)
local db=getDB()
local a=db.anchors and db.anchors[channelID]
if type(a)~="table"
or type(a.point)~="string"
or type(a.x)~="number"
or type(a.y)~="number"then
return nil
end
return{point=a.point,relPoint=a.relPoint or"CENTER",x=a.x,y=a.y}
end
function A:SetPosition(channelID,pos)
local db=getDB()
db.anchors=db.anchors or{}
db.anchors[channelID]={
point=pos.point,relPoint=pos.relPoint,x=pos.x,y=pos.y,
}
local ch=T.Notify:GetChannel(channelID)
if ch and ch.Reposition then pcall(ch.Reposition,ch)end
A:_syncBarPosition(channelID)
T:Fire("NOTIFY_ANCHOR_MOVED",channelID,db.anchors[channelID])
end
function A:NotifyChannelSettingsChanged(channelID)
local ch=T.Notify:GetChannel(channelID)
if ch and ch.UpdateAllSettings then pcall(ch.UpdateAllSettings,ch)end
A:_syncBarPosition(channelID)
end
function A:IsAnchorVisible(channelID)
local db=getDB()
local visibility=db and db.anchorVisibility
local registry=T.Notify._channelRegistry
if registry and registry.isEnabled then
return registry.isEnabled(channelID,visibility)
end
return type(visibility)~="table"
or visibility[channelID]~=false
end
function A:ApplyAnchorVisibility(channelID)
local bar=A._anchorBars[channelID]
if not bar then return end
if A:IsAnchorVisible(channelID)then
bar:Show()
if not A._demoTickers[channelID]then startDemo(channelID)end
else
bar:Hide()
if bar._popup then bar._popup:Hide()end
stopDemo(channelID)
end
end
function A:SetAnchorVisible(channelID,visible)
local db=getDB()
db.anchorVisibility=type(db.anchorVisibility)=="table"
and db.anchorVisibility or{}
db.anchorVisibility[channelID]=visible and true or false
if not visible and T.Notify._engine
and T.Notify._engine.CancelChannel then
T.Notify._engine:CancelChannel(channelID)
end
A:ApplyAnchorVisibility(channelID)
T:Fire("NOTIFY_ANCHOR_VISIBILITY_CHANGED",channelID,visible and true or false)
end
function A:_calcBarOffset(channelID,settings)
local gap=4
local halfBar=ANCHOR_HEIGHT/2
if channelID=="BAR"or channelID=="HEALTHBAR"then
local h=settings.height or 40
local off=h/2+halfBar+gap
return 0,(settings.grow=="DOWN")and off or-off
elseif channelID=="TICKBAR"then
local h=settings.height or 40
local off=h/2+halfBar+gap
return 0,(settings.grow=="DOWN")and off or-off
elseif channelID=="TEXT"or channelID=="SERPENT_FURY"then
local s=settings.size or 32
local off=s/2+halfBar+gap
return 0,(settings.grow=="DOWN")and off or-off
elseif channelID=="ICON"then
local s=settings.size or 50
local off=s/2+halfBar+gap
local grow=settings.grow or"UP"
if grow=="UP"then return 0,-off
elseif grow=="DOWN"then return 0,off
elseif grow=="LEFT"then return off,0
elseif grow=="RIGHT"then return-off,0 end
return 0,-off
elseif channelID=="CIRCLE"then
local s=settings.size or 110
return 0,-(s/2+halfBar+gap)
elseif channelID=="TIMELINE"then
local len=settings.length or 400
local sz=settings.iconSize or 32
if settings.orientation=="VERTICAL"then
return 0,-(len/2+halfBar+gap)
else
return 0,-(sz/2+halfBar+gap)
end
end
return 0,0
end
function A:_syncBarPosition(channelID)
local bar=A._anchorBars[channelID]
if not bar then return end
local pos=A:GetPosition(channelID)
if not pos then return end
local settings=getDB().channelDefaults[channelID]
if not settings then return end
local ox,oy=A:_calcBarOffset(channelID,settings)
bar:ClearAllPoints()
bar:SetPoint(pos.point,UIParent,pos.relPoint,pos.x+ox,pos.y+oy)
end
A._openDropdownMenu=nil
local function closeOpenDropdown()
if A._openDropdownMenu then
A._openDropdownMenu:Hide()
A._openDropdownMenu=nil
end
end
local function buildDropdown(parent,label,options,getValue,onSelect,width,maxVisibleItems)
local DD_W=width or 110
local container=CreateFrame("Frame",nil,parent)
container:SetSize(DD_W,36)
if label and label~=""then
local lbl=container:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
lbl:SetPoint("TOPLEFT",0,0)
lbl:SetText(label)
lbl:SetTextColor(1,0.82,0.30,1)
end
local btn=CreateFrame("Button",nil,container,"BackdropTemplate")
btn:SetSize(DD_W,18)
btn:SetPoint("BOTTOMLEFT",0,0)
btn:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
btn:SetBackdropColor(0.10,0.12,0.18,0.95)
btn:SetBackdropBorderColor(0.4,0.45,0.55,1)
local valueText=btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
valueText:SetPoint("LEFT",6,0)
valueText:SetPoint("RIGHT",-16,0)
valueText:SetJustifyH("LEFT")
valueText:SetWordWrap(false)
local arrow=btn:CreateFontString(nil,"OVERLAY","GameFontNormal")
arrow:SetPoint("RIGHT",-4,0)
arrow:SetText("v")
arrow:SetTextColor(0.7,0.7,0.75)
local function refresh()
local cur=getValue()
for _,opt in ipairs(options)do
if opt.value==cur then valueText:SetText(opt.text);return end
end
valueText:SetText(tostring(cur))
end
refresh()
local ITEM_H=20
local MENU_PAD=3
local visibleN=(maxVisibleItems and#options>maxVisibleItems)and maxVisibleItems or#options
local menuH=visibleN*ITEM_H+MENU_PAD*2
local needScroll=#options>visibleN
local SCROLL_GUTTER=needScroll and 18 or 0
local menu=CreateFrame("Frame",nil,btn,"BackdropTemplate")
menu:SetFrameStrata("TOOLTIP")
menu:SetSize(DD_W,menuH)
menu:SetPoint("TOPLEFT",btn,"BOTTOMLEFT",0,-2)
menu:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
menu:SetBackdropColor(0.06,0.07,0.10,0.97)
menu:SetBackdropBorderColor(0.4,0.45,0.55,1)
menu:Hide()
local listParent=menu
if needScroll then
local sf=CreateFrame("ScrollFrame",nil,menu,"UIPanelScrollFrameTemplate")
sf:SetPoint("TOPLEFT",MENU_PAD,-MENU_PAD)
sf:SetPoint("BOTTOMRIGHT",-MENU_PAD-SCROLL_GUTTER,MENU_PAD)
local content=CreateFrame("Frame",nil,sf)
content:SetSize(DD_W-MENU_PAD*2-SCROLL_GUTTER,#options*ITEM_H)
sf:SetScrollChild(content)
listParent=content
end
for i,opt in ipairs(options)do
local item=CreateFrame("Button",nil,listParent)
item:SetSize(DD_W-MENU_PAD*2-SCROLL_GUTTER,ITEM_H)
if needScroll then
item:SetPoint("TOPLEFT",0,-(i-1)*ITEM_H)
else
item:SetPoint("TOPLEFT",MENU_PAD,-MENU_PAD-(i-1)*ITEM_H)
end
local hl=item:CreateTexture(nil,"BACKGROUND")
hl:SetAllPoints()
hl:SetColorTexture(1,1,1,0.10)
hl:Hide()
local check=item:CreateFontString(nil,"OVERLAY","GameFontNormal")
check:SetPoint("LEFT",4,0)
check:SetText("")
check:SetTextColor(1,0.82,0.30,1)
local fs=item:CreateFontString(nil,"OVERLAY","GameFontNormal")
fs:SetPoint("LEFT",16,0)
fs:SetPoint("RIGHT",-4,0)
fs:SetText(opt.text)
fs:SetJustifyH("LEFT")
fs:SetWordWrap(false)
fs:SetTextColor(1,1,1)
item:SetScript("OnEnter",function()hl:Show()end)
item:SetScript("OnLeave",function()hl:Hide()end)
item:SetScript("OnClick",function()
onSelect(opt.value)
refresh()
menu:Hide()
A._openDropdownMenu=nil
end)
item._check=check
menu[i]=item
end
local function refreshMarks()
local cur=getValue()
for i,opt in ipairs(options)do
menu[i]._check:SetText(opt.value==cur and"v"or"")
end
end
btn:SetScript("OnClick",function()
if menu:IsShown()then
menu:Hide()
A._openDropdownMenu=nil
return
end
closeOpenDropdown()
refreshMarks()
menu:Show()
A._openDropdownMenu=menu
end)
container.refresh=refresh
return container
end
A._buildDropdown=buildDropdown
A._closeOpenDropdown=closeOpenDropdown
local LOGICAL_H={
dropdown=42,
slider=60,
check=26,
color=42,
}
local function renderSchema(popup,settings,schema,onChange)
local PAD_X=12
local PAD_TOP=14
local PAD_BOTTOM=16
local COL_W=110
local COL_GAP=8
local ROW_GAP=10
local cols=3
local items={}
for _,field in ipairs(schema)do
local widget,h
if field.type=="dropdown"then
widget=buildDropdown(popup,field.label,field.options,
function()return settings[field.key]end,
function(v)settings[field.key]=v;onChange()end)
h=LOGICAL_H.dropdown
elseif field.type=="slider"then
widget=CreateFrame("Frame",nil,popup)
local lbl=widget:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
lbl:SetPoint("TOPLEFT",0,0)
lbl:SetText(field.label)
lbl:SetTextColor(1,0.82,0.30,1)
local s=W:Slider(widget,field.min,field.max,field.step or 1)
s:SetSize(COL_W,16)
s:SetPoint("TOPLEFT",0,-18)
s:SetValue(settings[field.key]or field.min)
s:OnChange_(function(_,v)
v=math.floor(v+0.5)
settings[field.key]=v
onChange()
end)
h=LOGICAL_H.slider
widget:SetSize(COL_W,h)
elseif field.type=="check"then
widget=W:Check(popup,field.label)
widget:SetSize(COL_W,22)
widget:SetChecked_(settings[field.key]and true or false)
widget:OnChange_(function(_,v)
settings[field.key]=v
onChange()
end)
h=LOGICAL_H.check
elseif field.type=="color"then
widget=CreateFrame("Frame",nil,popup)
local lbl=widget:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
lbl:SetPoint("TOPLEFT",0,0)
lbl:SetText(field.label)
lbl:SetTextColor(1,0.82,0.30,1)
local swatch=W:ColorSwatch(widget,
function()return settings[field.key]or field.default end,
function(r,g,b)
settings[field.key]={r,g,b}
onChange()
end)
swatch:SetSize(44,18)
swatch:SetPoint("TOPLEFT",0,-18)
h=LOGICAL_H.color
widget:SetSize(COL_W,h)
end
if widget then
items[#items+1]={widget=widget,h=h}
end
end
local y=-PAD_TOP
local ix=0
local rowMaxH=0
for i,item in ipairs(items)do
if ix==0 then rowMaxH=0 end
item.widget:ClearAllPoints()
item.widget:SetPoint("TOPLEFT",popup,"TOPLEFT",
PAD_X+ix*(COL_W+COL_GAP),y)
if item.h>rowMaxH then rowMaxH=item.h end
ix=ix+1
if ix>=cols then
ix=0
y=y-rowMaxH
if i<#items then y=y-ROW_GAP end
end
end
if ix>0 then
y=y-rowMaxH
end
local needed_w=cols*COL_W+(cols-1)*COL_GAP+2*PAD_X
return-y+PAD_BOTTOM,needed_w
end
createSettingsPopup=function(bar,channelID)
local popup=CreateFrame("Frame",nil,bar,"BackdropTemplate")
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
popup:SetBackdropColor(0.10,0.18,0.36,0.96)
popup:SetBackdropBorderColor(0.4,0.6,0.85,1)
popup:ClearAllPoints()
popup:SetPoint("TOP",bar,"BOTTOM",0,-3)
popup:Hide()
local ch=T.Notify:GetChannel(channelID)
local db=getDB()
local settings=db.channelDefaults[channelID]
local schema=ch and ch.settingsSchema
if schema then
local h,w=renderSchema(popup,settings,schema,function()
A:NotifyChannelSettingsChanged(channelID)
end)
popup:SetSize(math.max(ANCHOR_WIDTH,w or ANCHOR_WIDTH),h)
else
popup:SetSize(ANCHOR_WIDTH,80)
end
return popup
end
local function findChannelMeta(channelID)
for _,m in ipairs(T.Notify:ListChannels())do
if m.id==channelID then return m end
end
end
local function createAnchorBar(channelID)
local meta=findChannelMeta(channelID)
if not meta then return nil end
local pos=A:GetPosition(channelID)or
{point="CENTER",relPoint="CENTER",x=0,y=0}
local settings=getDB().channelDefaults[channelID]or{}
local ox,oy=A:_calcBarOffset(channelID,settings)
local bar=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
bar:SetSize(ANCHOR_WIDTH,ANCHOR_HEIGHT)
bar:SetFrameStrata("DIALOG")
bar:SetPoint(pos.point,UIParent,pos.relPoint,pos.x+ox,pos.y+oy)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetBackdrop({
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
bar:SetBackdropBorderColor(0,0,0,0.85)
local bg=bar:CreateTexture(nil,"BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.20,0.55,0.20,0.85)
local hover=bar:CreateTexture(nil,"BORDER")
hover:SetAllPoints()
hover:SetColorTexture(1,1,1,0.10)
hover:Hide()
local label=bar:CreateFontString(nil,"OVERLAY","GameFontNormal")
label:SetPoint("CENTER",0,0)
label:SetText(meta.displayName or channelID)
label:SetTextColor(1,1,1,1)
local cog=CreateFrame("Button",nil,bar)
cog:SetSize(ANCHOR_HEIGHT-4,ANCHOR_HEIGHT-4)
cog:SetPoint("RIGHT",-2,0)
local cogTex=cog:CreateTexture(nil,"OVERLAY")
cogTex:SetAllPoints()
cogTex:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
cogTex:SetVertexColor(1,1,1,0.9)
bar:SetScript("OnEnter",function()hover:Show()end)
bar:SetScript("OnLeave",function()hover:Hide()end)
local function barCenterOffset(self)
local l,b=self:GetLeft(),self:GetBottom()
if not l or not b then return 0,0 end
local w,h=self:GetSize()
local uiW,uiH=UIParent:GetWidth(),UIParent:GetHeight()
return(l+w/2)-uiW/2,(b+h/2)-uiH/2
end
bar:SetScript("OnDragStart",function(self)
self:StartMoving()
self:SetScript("OnUpdate",function(s)
local cx,cy=barCenterOffset(s)
local cs=getDB().channelDefaults[channelID]or{}
local dx,dy=A:_calcBarOffset(channelID,cs)
local db=getDB()
db.anchors=db.anchors or{}
db.anchors[channelID]={
point="CENTER",relPoint="CENTER",
x=cx-dx,y=cy-dy,
}
local ch=T.Notify:GetChannel(channelID)
if ch and ch.Reposition then pcall(ch.Reposition,ch)end
end)
end)
bar:SetScript("OnDragStop",function(self)
self:StopMovingOrSizing()
self:SetScript("OnUpdate",nil)
local cx,cy=barCenterOffset(self)
local s=getDB().channelDefaults[channelID]or{}
local dx,dy=A:_calcBarOffset(channelID,s)
A:SetPosition(channelID,{
point="CENTER",relPoint="CENTER",
x=cx-dx,y=cy-dy,
})
end)
bar.channelID=channelID
cog:SetScript("OnClick",function()
if not bar._popup then
bar._popup=createSettingsPopup(bar,channelID)
end
if bar._popup:IsShown()then
bar._popup:Hide()
else
for _,otherBar in pairs(A._anchorBars)do
if otherBar~=bar and otherBar._popup then otherBar._popup:Hide()end
end
bar._popup:Show()
end
end)
return bar
end
local function createAnchorWindow()
local f=CreateFrame("Frame","SszorakFixedDirection_NotifyAnchorEditor",UIParent,"BackdropTemplate")
f:SetSize(PANEL_W,PANEL_H)
f:SetFrameStrata("FULLSCREEN_DIALOG")
f:SetPoint("TOP",UIParent,"TOP",0,-80)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart",f.StartMoving)
f:SetScript("OnDragStop",f.StopMovingOrSizing)
f:SetBackdrop({
bgFile="Interface\\Buttons\\WHITE8x8",
edgeFile="Interface\\Buttons\\WHITE8x8",
edgeSize=1,
})
f:SetBackdropColor(0.10,0.18,0.36,0.92)
f:SetBackdropBorderColor(0.4,0.6,0.85,1)
local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
title:SetPoint("TOP",0,-6)
title:SetText(L.notify_anchor_panel_title or"锚点配置")
title:SetTextColor(0.85,0.9,1.0)
local layout={{id="TEXT",key="notify_anchor_show_text",col=1,row=1},{id="SERPENT_FURY",key="notify_anchor_show_serpent",col=2,row=1}}
local checks={}
for _,item in ipairs(layout)do
local cb=W:Check(f,L[item.key]or item.id)
cb:SetSize(160,22)
cb:SetPoint("TOPLEFT",12+(item.col-1)*170,-22-(item.row-1)*26)
cb:SetChecked_(A:IsAnchorVisible(item.id))
cb:OnChange_(function(_,checked)
A:SetAnchorVisible(item.id,checked)
end)
checks[item.id]=cb
end
f._checks=checks
local BTN_W,BTN_GAP=120,8
local resetBtn=W:Button(f,L.notify_anchor_reset or"重置")
resetBtn:SetSize(BTN_W,24)
resetBtn:SetPoint("BOTTOM",-(BTN_W+BTN_GAP)/2,8)
resetBtn:SetScript("OnClick",function()
StaticPopup_Show("SszorakFixedDirection_NOTIFY_ANCHOR_RESET")
end)
local exitBtn=W:Button(f,L.notify_anchor_exit or"退出配置")
exitBtn:SetSize(BTN_W,24)
exitBtn:SetPoint("BOTTOM",(BTN_W+BTN_GAP)/2,8)
exitBtn:SetScript("OnClick",function()A:ExitEditMode()end)
tinsert(UISpecialFrames,"SszorakFixedDirection_NotifyAnchorEditor")
f:HookScript("OnHide",function()
if A._editing and not InCombatLockdown()then A:ExitEditMode()end
end)
return f
end
startDemo=function(channelID)
local function fire()
T.Notify:Schedule({
fireAt=GetTime()+0.05,
channels={[channelID]=randomDemoSample(channelID)},
tag="anchor_demo_"..channelID,
})
end
fire()
A._demoTickers[channelID]=C_Timer.NewTicker(DEMO_REFRESH,fire)
end
stopDemo=function(channelID)
T.Notify:CancelByTag("anchor_demo_"..channelID)
if A._demoTickers[channelID]then
A._demoTickers[channelID]:Cancel()
A._demoTickers[channelID]=nil
end
end
local function performReset()
local db=getDB()
if type(db.anchors)=="table"then wipe(db.anchors)end
if type(db.channelDefaults)=="table"then wipe(db.channelDefaults)end
if type(db.anchorVisibility)=="table"then wipe(db.anchorVisibility)end
for _,meta in ipairs(T.Notify:ListChannels())do
local spec=T.Notify:GetChannel(meta.id)
if spec and spec.OnInit then pcall(spec.OnInit,spec)end
end
for cid,bar in pairs(A._anchorBars)do
bar:Hide()
if bar._popup then bar._popup:Hide()end
stopDemo(cid)
end
wipe(A._anchorBars)
if T.Notify and T.Notify.CancelByTag then
T.Notify:CancelByTag("anchor_demo")
end
if not A._editing then return end
for _,meta in ipairs(T.Notify:ListChannels())do
if isVisualChannel(meta)then
local cid=meta.id
local ok,err=pcall(function()
A._anchorBars[cid]=createAnchorBar(cid)
if A._anchorBars[cid]then
A:ApplyAnchorVisibility(cid)
end
end)
if not ok then
print(string.format(
"|cffff4444[SszorakFixedDirection/Notify]|r reset 后创建 anchor 失败 [%s]：%s",
cid,tostring(err)))
end
end
end
if A._controlPanel and A._controlPanel._checks then
for _,cb in pairs(A._controlPanel._checks)do
cb:SetChecked_(true)
end
end
end
pcall(function()
StaticPopupDialogs["SszorakFixedDirection_NOTIFY_ANCHOR_RESET"]={
text=L.notify_anchor_reset_confirm
or"确定要把所有锚点位置和通道样式重置到默认吗？",
button1="确定",
button2="取消",
OnAccept=performReset,
OnShow=function(self)self:SetFrameStrata("TOOLTIP")end,
timeout=0,
whileDead=true,
hideOnEscape=true,
preferredIndex=3,
}
end)
local function ensureCombatWatcher()
if A._combatWatcher then return A._combatWatcher end
local watcher=CreateFrame("Frame")
watcher:SetScript("OnEvent",function()
A:HandleCombatStart()
end)
A._combatWatcher=watcher
return watcher
end
function A:HandleCombatStart()
if A._editing then A:ExitEditMode(true)end
end
function A:EnterEditMode(reopenInfo)
if A._editing or InCombatLockdown()then return end
A._editing=true
ensureCombatWatcher():RegisterEvent("PLAYER_REGEN_DISABLED")
if reopenInfo then
A._reopenInfo=reopenInfo
elseif T.Options and T.Options.frame and T.Options.frame:IsShown()then
A._reopenInfo={
kind="options",
module=(T.Options._currentMod and T.Options._currentMod.name)or true,
}
T.Options.frame:Hide()
else
A._reopenInfo=nil
end
A._reopenAfter=A._reopenInfo and A._reopenInfo.module or nil
if not A._controlPanel then
A._controlPanel=createAnchorWindow()
end
for cid,cb in pairs(A._controlPanel._checks or{})do
cb:SetChecked_(A:IsAnchorVisible(cid))
end
A._controlPanel:Show()
for _,meta in ipairs(T.Notify:ListChannels())do
if isVisualChannel(meta)then
local cid=meta.id
local ok,err=pcall(function()
if not A._anchorBars[cid]then
A._anchorBars[cid]=createAnchorBar(cid)
end
if A._anchorBars[cid]then
A:ApplyAnchorVisibility(cid)
end
end)
if not ok then
print(string.format(
"|cffff4444[SszorakFixedDirection/Notify]|r anchor 创建失败 [%s]：%s",
cid,tostring(err)))
end
end
end
T:Fire("NOTIFY_EDIT_MODE_CHANGED",true)
end
function A:ExitEditMode(suppressReopen)
A._editing=false
if A._combatWatcher then
A._combatWatcher:UnregisterEvent("PLAYER_REGEN_DISABLED")
end
closeOpenDropdown()
T.Notify:CancelByTag("anchor_demo")
for cid,bar in pairs(A._anchorBars)do
bar:Hide()
if bar._popup then bar._popup:Hide()end
stopDemo(cid)
end
if A._controlPanel then A._controlPanel:Hide()end
T:Fire("NOTIFY_EDIT_MODE_CHANGED",false)
local r=A._reopenInfo
A._reopenInfo=nil
A._reopenAfter=nil
if suppressReopen then return end
if r then
if r.kind=="options"and T.Options and T.Options.Open then
if r.module==true or r.module==nil then
T.Options:Open()
else
T.Options:Open(r.module)
end
elseif r.kind=="timeline"then
local tlMod=T.moduleMap and T.moduleMap["Timeline"]
if tlMod and tlMod.ShowTimeline then
tlMod:ShowTimeline()
end
elseif r.kind=="boss_module"then
local editor=T.BossModule and T.BossModule.Editor
if editor and r.encID and r.templateId then
if r.readOnly and editor.OpenBuiltin then
editor.OpenBuiltin(r.encID,r.templateId)
elseif editor.Open then
editor.Open(r.encID,r.templateId)
end
end
end
end
end
function A:IsEditing()return A._editing end
