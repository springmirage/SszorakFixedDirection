local T,C,L=unpack(SszorakFixedDirection)
local format=string.format
local max=math.max
local InCombatLockdown=InCombatLockdown
local W={}
T.W=W
function W:ConfigureKeyboardInput(frame,enabled,propagate)
if not frame or not frame.EnableKeyboard then return false end
if InCombatLockdown and InCombatLockdown()then return false end
if propagate~=nil and frame.SetPropagateKeyboardInput then
frame:SetPropagateKeyboardInput(propagate and true or false)
end
frame:EnableKeyboard(enabled and true or false)
return true
end
local function applyMixin(f)
f.Point=function(self,...)
self:SetPoint(...)
return self
end
f.Size=function(self,w,h)
self:SetSize(w,h)
return self
end
f.OnShow_=function(self,fn)
self:SetScript("OnShow",fn)
return self
end
f.OnHide_=function(self,fn)
self:SetScript("OnHide",fn)
return self
end
f.Tooltip_=function(self,text)
self:SetScript("OnEnter",function(btn)
GameTooltip:SetOwner(btn,"ANCHOR_RIGHT")
GameTooltip:AddLine(text,1,1,1,true)
GameTooltip:Show()
end)
self:SetScript("OnLeave",function()
GameTooltip:Hide()
end)
return self
end
return f
end
local WHITE="Interface\\Buttons\\WHITE8x8"
local function solidTex(parent,layer,r,g,b,a)
local t=parent:CreateTexture(nil,layer or"BACKGROUND")
t:SetTexture(WHITE)
t:SetVertexColor(r or 0,g or 0,b or 0,a or 1)
return t
end
function W:Frame(parent)
local f=CreateFrame("Frame",nil,parent)
return applyMixin(f)
end
function W:BackdropFrame(parent,bgR,bgG,bgB,bgA,brR,brG,brB,brA)
local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
f:SetBackdrop({
bgFile=WHITE,
edgeFile=WHITE,
edgeSize=1,
})
f:SetBackdropColor(bgR or 0,bgG or 0,bgB or 0,bgA or 0.85)
f:SetBackdropBorderColor(brR or 0.25,brG or 0.25,brB or 0.28,brA or 1)
return applyMixin(f)
end
function W:Button(parent,text)
local f=CreateFrame("Button",nil,parent)
applyMixin(f)
local bg=solidTex(f,"BACKGROUND",0.18,0.18,0.2,0.9)
bg:SetAllPoints()
f.bg=bg
local hl=solidTex(f,"HIGHLIGHT",1,1,1,0.1)
hl:SetAllPoints()
f:SetScript("OnMouseDown",function(self)
self.label:SetPoint("CENTER",0,-1)
end)
f:SetScript("OnMouseUp",function(self)
self.label:SetPoint("CENTER",0,0)
end)
local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
label:SetPoint("CENTER",0,0)
label:SetText(text or"")
f.label=label
f.SetText_=function(self,t)
self.label:SetText(t)
return self
end
f.OnClick_=function(self,fn)
self:SetScript("OnClick",fn)
return self
end
return f
end
function W:Dropdown(parent)
local btn=self:Button(parent,"")
btn._items={}
btn.SetPlaceholder_=function(self,text)
self._placeholder=text
return self
end
btn.SetValue_=function(self,v)
self._value=v
for _,item in ipairs(self._items)do
if item.value==v then
self:SetText_(item.text)
return self
end
end
self:SetText_(self._placeholder or(v~=nil and tostring(v))or"")
return self
end
btn.SetItems_=function(self,items)
self._items=items or{}
return self:SetValue_(self._value)
end
btn.GetValue_=function(self)return self._value end
btn.OnPick_=function(self,fn)
self._onPick=fn
return self
end
btn:OnClick_(function()
if#btn._items==0 then return end
local menu={}
for _,item in ipairs(btn._items)do
menu[#menu+1]={
text=item.text,
func=function()
btn:SetValue_(item.value)
if btn._onPick then btn._onPick(item.value,item)end
end,
}
end
W:ContextMenu(menu,btn)
end)
return btn
end
function W:Check(parent,text)
local f=CreateFrame("Frame",nil,parent)
applyMixin(f)
f:SetSize(300,22)
local box=CreateFrame("Button",nil,f)
box:SetSize(16,16)
box:SetPoint("LEFT",0,0)
f.box=box
local boxBg=solidTex(box,"BACKGROUND",0.15,0.15,0.17,0.95)
boxBg:SetAllPoints()
local boxBorder=CreateFrame("Frame",nil,box,"BackdropTemplate")
boxBorder:SetAllPoints()
boxBorder:SetBackdrop({edgeFile=WHITE,edgeSize=1})
boxBorder:SetBackdropBorderColor(0.4,0.4,0.45,1)
local check=box:CreateTexture(nil,"OVERLAY")
check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
check:SetAllPoints()
check:Hide()
f.checkTex=check
local partial=box:CreateTexture(nil,"OVERLAY")
partial:SetTexture(WHITE)
partial:SetVertexColor(0.95,0.82,0.3,1)
partial:SetPoint("TOPLEFT",4,-4)
partial:SetPoint("BOTTOMRIGHT",-4,4)
partial:Hide()
f.partialTex=partial
if text then
local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
label:SetPoint("LEFT",box,"RIGHT",5,0)
label:SetText(text)
f.label=label
end
f.state="unchecked"
local function render(self)
if self.state=="checked"then
check:Show();partial:Hide()
elseif self.state=="partial"then
check:Hide();partial:Show()
else
check:Hide();partial:Hide()
end
end
box:SetScript("OnClick",function()
if f.state=="checked"then
f.state="unchecked"
else
f.state="checked"
end
render(f)
if f.onChange then f:onChange(f.state=="checked")end
end)
box:SetScript("OnEnter",function()
boxBorder:SetBackdropBorderColor(0.8,0.8,0.9,1)
end)
box:SetScript("OnLeave",function()
boxBorder:SetBackdropBorderColor(0.4,0.4,0.45,1)
end)
f.SetChecked_=function(self,val)
self.state=val and"checked"or"unchecked"
render(self)
return self
end
f.SetState_=function(self,s)
if s~="checked"and s~="unchecked"and s~="partial"then
s="unchecked"
end
self.state=s
render(self)
return self
end
f.GetChecked_=function(self)return self.state=="checked"end
f.GetState_=function(self)return self.state end
f.SetEnabled_=function(self,enabled)
enabled=enabled and true or false
box:SetEnabled(enabled)
self:SetAlpha(enabled and 1 or 0.45)
return self
end
f.OnChange_=function(self,fn)
self.onChange=fn
return self
end
return f
end
function W:Slider(parent,minVal,maxVal,step)
local f=CreateFrame("Slider",nil,parent)
applyMixin(f)
f:SetHeight(16)
f:SetOrientation("HORIZONTAL")
f:SetMinMaxValues(minVal or 0,maxVal or 100)
f:SetValueStep(step or 1)
f:SetObeyStepOnDrag(true)
f:EnableMouse(true)
local track=solidTex(f,"BACKGROUND",0.15,0.15,0.17,0.95)
track:SetPoint("LEFT",4,0)
track:SetPoint("RIGHT",-4,0)
track:SetHeight(4)
local thumb=f:CreateTexture(nil,"OVERLAY")
thumb:SetTexture(WHITE)
thumb:SetVertexColor(0.8,0.75,0.3,1)
thumb:SetSize(8,16)
f:SetThumbTexture(thumb)
local valueText=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
valueText:SetPoint("TOP",f,"BOTTOM",0,-2)
f.valueText=valueText
f._valueFmt="%.0f"
f:SetScript("OnValueChanged",function(self,val)
valueText:SetText(format(self._valueFmt or"%.0f",val))
if self.onChange then self:onChange(val)end
end)
f.OnChange_=function(self,fn)
self.onChange=fn
return self
end
f.SetValue_=function(self,val)
self:SetValue(val)
return self
end
f.SetValueFormat_=function(self,fmt)
self._valueFmt="%"..(fmt or".0f")
local v=self:GetValue()
if v~=nil then valueText:SetText(format(self._valueFmt,v))end
return self
end
return f
end
function W:Section(parent,title)
local f=CreateFrame("Frame",nil,parent)
applyMixin(f)
f:SetHeight(24)
local line=solidTex(f,"ARTWORK",0.3,0.3,0.35,0.9)
line:SetPoint("LEFT",0,0)
line:SetPoint("RIGHT",0,0)
line:SetHeight(1)
local label=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
label:SetPoint("BOTTOMLEFT",0,2)
label:SetText(title or"")
label:SetTextColor(0.6,0.6,0.65,1)
local labelBg=solidTex(f,"ARTWORK",0.1,0.1,0.12,1)
labelBg:SetPoint("TOPLEFT",label,"TOPLEFT",-2,2)
labelBg:SetPoint("BOTTOMRIGHT",label,"BOTTOMRIGHT",2,-2)
label:SetDrawLayer("OVERLAY",1)
f.label=label
f.SetTitle_=function(self,t)
self.label:SetText(t)
return self
end
return f
end
local ctxMenu
local ctxItems={}
local function ensureCtxMenu()
if ctxMenu then return ctxMenu end
local m=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
m:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
m:SetBackdropColor(0.06,0.07,0.10,0.97)
m:SetBackdropBorderColor(0.3,0.3,0.35,1)
m:SetFrameStrata("FULLSCREEN_DIALOG")
m:SetFrameLevel(1000)
m:SetClampedToScreen(true)
if m.SetToplevel then m:SetToplevel(true)end
m:Hide()
local closer=CreateFrame("Button",nil,UIParent)
closer:SetAllPoints(UIParent)
closer:SetFrameStrata("FULLSCREEN_DIALOG")
closer:SetFrameLevel(999)
closer:RegisterForClicks("AnyUp")
closer:Hide()
closer:SetScript("OnClick",function()m:Hide();closer:Hide()end)
m._closer=closer
m:SetScript("OnShow",function()closer:Show()end)
m:SetScript("OnHide",function()closer:Hide()end)
ctxMenu=m
return m
end
local function acquireItem(parent)
local it=table.remove(ctxItems)
if it then
it:SetParent(parent)
it:ClearAllPoints()
it:SetHeight(22)
it:EnableMouse(true)
if it.bg then it.bg:SetVertexColor(0,0,0,0)end
return it
end
it=CreateFrame("Button",nil,parent)
it:SetHeight(22)
it.bg=it:CreateTexture(nil,"BACKGROUND");it.bg:SetAllPoints();it.bg:SetTexture(WHITE)
it.bg:SetVertexColor(0,0,0,0)
it:SetScript("OnEnter",function(self)self.bg:SetVertexColor(0.2,0.3,0.6,0.5)end)
it:SetScript("OnLeave",function(self)self.bg:SetVertexColor(0,0,0,0)end)
it.fs=it:CreateFontString(nil,"OVERLAY","GameFontNormal")
it.fs:SetPoint("LEFT",10,0)
return it
end
local function releaseItems(list)
for _,it in ipairs(list)do
it:Hide()
it:SetScript("OnClick",nil)
table.insert(ctxItems,it)
end
wipe(list)
end
local shownItems={}
function W:ContextMenu(items,owner)
local m=ensureCtxMenu()
releaseItems(shownItems)
local ownerLevel=owner and owner.GetFrameLevel and owner:GetFrameLevel()or 0
local menuLevel=max(1000,ownerLevel+100)
m:SetFrameStrata("FULLSCREEN_DIALOG")
m:SetFrameLevel(menuLevel)
m._closer:SetFrameStrata("FULLSCREEN_DIALOG")
m._closer:SetFrameLevel(menuLevel-1)
local width=160
local y=-4
for _,entry in ipairs(items)do
if entry.separator then
local sep=acquireItem(m)
sep:SetWidth(width-8);sep:SetHeight(3)
sep:SetPoint("TOPLEFT",4,y)
sep.bg:SetVertexColor(0.25,0.25,0.3,1)
sep.fs:SetText("")
sep:EnableMouse(false)
sep:Show()
shownItems[#shownItems+1]=sep
y=y-5
else
local it=acquireItem(m)
it:SetWidth(width-8)
it:SetPoint("TOPLEFT",4,y)
it.fs:SetText(entry.text or"")
if entry.disabled then
it.fs:SetTextColor(0.5,0.5,0.5,1)
it:EnableMouse(false)
else
it.fs:SetTextColor(1,1,1,1)
it:EnableMouse(true)
it:SetScript("OnClick",function()
m:Hide()
if entry.func then entry.func()end
end)
end
it:Show()
shownItems[#shownItems+1]=it
y=y-22
end
end
m:SetSize(width,-y+4)
local scale=UIParent:GetEffectiveScale()
local cx,cy=GetCursorPosition()
m:ClearAllPoints()
m:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",cx/scale,cy/scale)
m:Show()
end
function W:KeybindButton(parent)
local f=CreateFrame("Button",nil,parent)
applyMixin(f)
f:SetSize(120,22)
local bg=solidTex(f,"BACKGROUND",0.14,0.14,0.18,0.9)
bg:SetAllPoints()
f.bg=bg
local hl=solidTex(f,"HIGHLIGHT",1,1,1,0.08)
hl:SetAllPoints()
local function edgeTex(edge)
local t=solidTex(f,"BORDER",0.30,0.35,0.45,0.7)
return t
end
local eT,eB,eL,eR=edgeTex(),edgeTex(),edgeTex(),edgeTex()
eT:SetPoint("TOPLEFT");eT:SetPoint("TOPRIGHT");eT:SetHeight(1)
eB:SetPoint("BOTTOMLEFT");eB:SetPoint("BOTTOMRIGHT");eB:SetHeight(1)
eL:SetPoint("TOPLEFT");eL:SetPoint("BOTTOMLEFT");eL:SetWidth(1)
eR:SetPoint("TOPRIGHT");eR:SetPoint("BOTTOMRIGHT");eR:SetWidth(1)
f._edges={eT,eB,eL,eR}
local function setEdgeColor(r,g,b,a)
for _,e in ipairs(f._edges)do e:SetVertexColor(r,g,b,a)end
end
local label=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
label:SetPoint("CENTER",0,0)
label:SetTextColor(0.92,0.92,0.96,1)
f.label=label
f._action=nil
f._capturing=false
local function refreshLabel(self)
if self._capturing then
self.label:SetText("|cffffd200"..(L and L.kb_capture_prompt or"按下任意键...").."|r")
return
end
if not self._action then
self.label:SetText("—")
return
end
local key=GetBindingKey(self._action)
if key and key~=""then
local pretty=(GetBindingText and GetBindingText(key,"KEY_"))or key
self.label:SetText(pretty)
else
self.label:SetText("|cff888888"..(L and L.kb_unset or"未设置").."|r")
end
end
f.Refresh_=refreshLabel
f.SetAction_=function(self,action)
self._action=action
refreshLabel(self)
return self
end
local function reportBindingFailure(err)
print("|cffff4444[SszorakFixedDirection]|r "..
(L and L.kb_apply_failed or"设置快捷键失败（战斗中？）：")
..tostring(err))
end
local function applyBinding(self,keyCombo)
if not self._action then return end
if not SetBinding then return end
if InCombatLockdown and InCombatLockdown()then
reportBindingFailure("combat_locked")
refreshLabel(self)
return
end
local function inner()
local prev1,prev2=GetBindingKey(self._action)
if prev1 then SetBinding(prev1,nil)end
if prev2 then SetBinding(prev2,nil)end
if keyCombo then SetBinding(keyCombo,self._action)end
local set=(GetCurrentBindingSet and GetCurrentBindingSet())or 2
if SaveBindings then SaveBindings(set)end
end
local ok,err=pcall(inner)
if not ok then reportBindingFailure(err)end
refreshLabel(self)
if self._onChanged then self._onChanged(self,keyCombo)end
end
f.OnChanged_=function(self,fn)self._onChanged=fn;return self end
local function exitCapture(self)
self._capturing=false
if W:ConfigureKeyboardInput(self,false)then
self:EnableMouseWheel(false)
self._captureExitPending=nil
else
self._captureExitPending=true
end
setEdgeColor(0.30,0.35,0.45,0.7)
self:SetScript("OnUpdate",nil)
refreshLabel(self)
end
local IGNORE_KEYS={
LSHIFT=true,RSHIFT=true,
LCTRL=true,RCTRL=true,
LALT=true,RALT=true,
UNKNOWN=true,
}
local function buildCombo(key)
local mods=""
if IsAltKeyDown()then mods=mods.."ALT-"end
if IsControlKeyDown()then mods=mods.."CTRL-"end
if IsShiftKeyDown()then mods=mods.."SHIFT-"end
return mods..key
end
f:SetScript("OnKeyDown",function(self,key)
if not self._capturing then
if W:ConfigureKeyboardInput(self,false,true)then
self:EnableMouseWheel(false)
self._captureExitPending=nil
else
self._captureExitPending=true
end
return
end
if not W:ConfigureKeyboardInput(self,true,false)then
reportBindingFailure("combat_locked")
exitCapture(self)
return
end
if key=="ESCAPE"then
exitCapture(self)
return
end
if IGNORE_KEYS[key]then return end
local combo=buildCombo(key)
exitCapture(self)
applyBinding(self,combo)
end)
f:SetScript("OnMouseWheel",function(self,delta)
if not self._capturing then return end
if InCombatLockdown and InCombatLockdown()then
reportBindingFailure("combat_locked")
exitCapture(self)
return
end
local combo=buildCombo(delta>0 and"MOUSEWHEELUP"or"MOUSEWHEELDOWN")
exitCapture(self)
applyBinding(self,combo)
end)
f:RegisterForClicks("LeftButtonUp","RightButtonUp")
f:SetScript("OnClick",function(self,button)
if button=="RightButton"then
applyBinding(self,nil)
return
end
if not W:ConfigureKeyboardInput(self,true,true)then
reportBindingFailure("combat_locked")
return
end
self._capturing=true
self:EnableMouseWheel(true)
setEdgeColor(1.0,0.82,0.20,1)
refreshLabel(self)
local elapsed=0
self:SetScript("OnUpdate",function(s,dt)
elapsed=elapsed+dt
if elapsed>8 then exitCapture(s)end
end)
end)
f:SetScript("OnHide",function(self)
if self._capturing then exitCapture(self)end
end)
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent",function(self)
if self._captureExitPending
and W:ConfigureKeyboardInput(self,false,true)
then
self:EnableMouseWheel(false)
self._captureExitPending=nil
end
end)
f:SetScript("OnEnter",function(self)
refreshLabel(self)
if GameTooltip and self._action then
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:AddLine((L and L.kb_tooltip)
or"右键: 清除   Esc: 取消",0.85,0.85,0.92,true)
GameTooltip:Show()
end
end)
f:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
return f
end
