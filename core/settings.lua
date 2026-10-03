local T=unpack(SszorakFixedDirection)
local W,H=T.W,T.TestHarness
local S={page="测试"};T.Settings=S
local ROLES={{value="TANK",text="坦克"},{value="RANGED_DPS",text="远程 DPS"},{value="RANGED_HEALER",text="远程治疗"},{value="MELEE_HEALER",text="近战治疗"},{value="MELEE",text="近战 DPS"}}
local STATUS={IDLE="未运行",RUNNING="运行中",PAUSED="暂停",COMPLETED="测试完成"}
local function clock(v)v=math.floor(v or 0);return string.format("%02d:%02d",math.floor(v/60),v%60)end
local function text(parent,value,x,y,width,size)
local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
fs:SetFont(STANDARD_TEXT_FONT,size or 14,"");fs:SetTextColor(.89,.92,.95)
fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);fs:SetJustifyH("LEFT")
if width then fs:SetWidth(width)end;fs:SetText(value);return fs
end
local function button(parent,label,x,y,width,callback)
local b=W:Button(parent,label);b:SetSize(width,30);b:SetPoint("TOPLEFT",x,y);b:OnClick_(callback);return b
end
local function dropdown(parent,label,x,y,items,value,callback)
text(parent,label,x,y,230,13)
local b=W:Dropdown(parent);b:SetPoint("TOPLEFT",x,y-23);b:SetSize(238,30)
b:SetItems_(items);b:SetValue_(value);b:OnPick_(callback);return b
end
local function checkbox(parent,label,x,y,value,callback)
local c=W:Check(parent,label);c:SetPoint("TOPLEFT",x,y);c:SetChecked_(value)
c.onChange=function(_,v)callback(v)end;return c
end
function S:HideLegacy()
local wind=T.moduleMap.WindOctagon
wind._reopenFn=nil;wind._compassReopenFn=nil
wind.CloseConfig();wind.CloseCompassConfig()
end
function S:OpenLegacy(compass)
if InCombatLockdown()then print("请脱战后调整位置。");return end
if H.active then H:Stop()end
self:HideLegacy()
if self.frame then self.frame:Hide()end
local back=function()S:Open("位置设置")end
local wind=T.moduleMap.WindOctagon
if compass then wind.OpenCompassConfig("SFD · 罗盘位置与预览",back)
else wind.OpenConfig("SFD · 发送 / 接收设置",back)end
end
function S:EditText()
if InCombatLockdown()then print("请脱战后调整位置。");return end
if H.active then H:Stop()end
self:HideLegacy();self.frame:Hide();self.anchorReopen=true
T.Notify.anchor:EnterEditMode()
end
function S:TestPoint(slot)
if InCombatLockdown()or(T.Fixed.active and not H.active)then print("战斗进行中，无法启动测试。");return end
self:HideLegacy();if self.frame then self.frame:Hide()end
H.slot=tostring(slot)
local window=T.moduleMap.OrbPositionAlert.WARNING_WINDOWS.M[slot]
if not H:Jump(window.at-.1)then return end
local fill=H.autoFill;H.autoFill=true;H:SeedMissing();H.autoFill=fill
H:AdvanceTo(window.at)
end
function S:TestSender()
if InCombatLockdown()or(T.Fixed.active and not H.active)then print("战斗进行中，无法启动测试。");return end
self:HideLegacy()
H:SetSender(true);H.autoFill=false
if H:Start()then
self.frame:Hide()
print("发送与接收测试已开始：点击三个风向，查看接收图标。不会发送团队消息。输入 /sfd 返回设置。")
end
end
function S:Select(page)
self.page=page
if page=="分担设置"and self.soakRows then self:RefreshSoakPage()end
for name,frame in pairs(self.pages)do frame:SetShown(name==page)end
for name,b in pairs(self.tabs)do b.label:SetTextColor(name==page and .41 or .65,name==page and .79 or .7,name==page and .68 or .74)end
end
function S:Create()
if self.frame then return end
local f=W:BackdropFrame(UIParent,.078,.094,.114,.98,.19,.22,.27,1)
self.frame=f;f:SetSize(760,660);f:SetPoint("CENTER")
f:SetScale(math.min(1,(UIParent:GetHeight()-50)/660))
f:SetFrameStrata("DIALOG");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart",function()f:StartMoving()end)
f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
text(f,"Sszorak Fixed Direction",24,-24,650,22)
text(f,"固定罗盘 · 放球提醒 · 脱战练习",24,-57,650,13)
button(f,"关闭",674,-24,62,function()f:Hide()end)
self.tabs={};self.pages={}
for i,name in ipairs({"常规","位置设置","测试","分担设置"})do
local page=name
self.tabs[name]=button(f,name,20,-104-(i-1)*44,126,function()S:Select(page)end)
local p=W:BackdropFrame(f,.106,.129,.157,1,.19,.22,.27,1)
p:SetPoint("TOPLEFT",166,-96);p:SetSize(574,544);self.pages[name]=p
end
local p=self.pages["常规"]
text(p,"常规",24,-22,510,20)
text(p,"先面对 BOSS，再按罗盘寻找放球图标。\n\n收到放球提醒后，按显示的标记前往对应位置。\n第四个放球点在 BOSS 脚下。\n\n每轮只需选择三次风向，囊肿放在风向对面。\n发送端由负责看风的玩家自行开启。",24,-70,510,15)
button(p,"打开位置设置",24,-300,310,function()S:Select("位置设置")end)
checkbox(p,"启用毒蛇之怒集合分担提醒",24,-355,T.moduleMap.SerpentFuryAlert.db.enabled,function(v)T.moduleMap.SerpentFuryAlert:SetEnabled(v)end)
p=self.pages["位置设置"]
text(p,"位置设置",24,-22,510,20)
text(p,"调整罗盘、发送面板、接收条和文字提示的位置。\n打开位置编辑会停止正在进行的测试。",24,-65,510,14)
button(p,"罗盘：预览 / 拖动 / 大小",24,-125,360,function()S:OpenLegacy(true)end)
button(p,"发送面板与接收条：设置 / 测试",24,-171,360,function()S:OpenLegacy(false)end)
button(p,"文字提示：位置 / 字号 / 对齐",24,-217,360,function()S:EditText()end)
button(p,"测试发送与接收",24,-263,360,function()S:TestSender()end)
text(p,"罗盘、接收条：解锁后拖动，可调整大小或重置位置。\n\n发送面板：勾选“脱战显示发送面板”，拖动面板底图。\n\n文字提示：拖动绿色条，点齿轮调整字号和对齐。\n\n测试发送与接收时，点击三个风向即可完成一轮。\n测试不会发送团队消息。",24,-315,510,14)
p=self.pages["测试"]
text(p,"脱战测试",24,-18,350,20)
text(p,"在脱战时练习提示与走位，不会发送团队消息。",24,-49,526,12)
self.status=text(p,"未运行",24,-78,250,16)
self.time=text(p,"00:00 / 06:30",352,-78,198,16)
local bg=p:CreateTexture(nil,"BACKGROUND");bg:SetPoint("TOPLEFT",24,-104);bg:SetSize(526,6);bg:SetColorTexture(.19,.22,.27,1)
self.progress=p:CreateTexture(nil,"ARTWORK");self.progress:SetPoint("TOPLEFT",24,-104);self.progress:SetSize(.1,6);self.progress:SetColorTexture(.41,.79,.68,1)
self.role=dropdown(p,"模拟职责",24,-126,ROLES,H.role,function(v)H:SelectRole(v)end)
local slots={{value="AUTO",text="自动轮换"}}
for i=1,4 do slots[#slots+1]={value=tostring(i),text="第"..i.."个放球点"}end
self.slot=dropdown(p,"模拟放球位置",310,-126,slots,H.slot,function(v)H.slot=v end)
text(p,"快速测试放球提示",24,-196,260,13)
for i=1,4 do local slot=i;button(p,"点"..i,24+(i-1)*60,-219,54,function()S:TestPoint(slot)end)end
self.speed=dropdown(p,"测试速度",310,-196,{{value=1,text="1x · 真实 6分30秒"},{value=2,text="2x"},{value=5,text="5x"},{value=10,text="10x · 39秒"}},H.speed,function(v)H:SetSpeed(v)end)
self.sender=checkbox(p,"模拟开启发送端",24,-267,H.sender,function(v)H:SetSender(v)end)
self.hud=checkbox(p,"显示测试状态悬浮窗",310,-267,H.showHUD,function(v)H.showHUD=v;S:Refresh()end)
self.fill=checkbox(p,"自动补齐测试风向",24,-298,H.autoFill,function(v)H.autoFill=v end)
self.controls={}
local actions={{"开始",function()H:Start()end},{"暂停",function()H:Pause()end},{"继续",function()H:Resume()end},{"停止",function()H:Stop()end},{"重新开始",function()H:Restart()end}}
for i,item in ipairs(actions)do self.controls[item[1]]=button(p,item[1],24+(i-1)*108,-333,98,item[2])end
text(p,"跳转",24,-383,50,14)
local edit=CreateFrame("EditBox",nil,p,"InputBoxTemplate")
edit:SetSize(92,28);edit:SetPoint("TOPLEFT",76,-377);edit:SetAutoFocus(false);edit:SetMaxLetters(5);edit:SetText("02:00")
edit:SetScript("OnEscapePressed",function(e)e:ClearFocus()end);self.jumpInput=edit
button(p,"跳转",180,-377,70,function()H:Jump(edit:GetText());edit:ClearFocus()end)
button(p,"00:20",282,-377,80,function()H:Jump(20)end)
button(p,"02:00",374,-377,80,function()H:Jump(120)end)
button(p,"05:00",466,-377,80,function()H:Jump(300)end)
self.summary=text(p,"",24,-424,526,13)
self:CreateSoakPage(self.pages["分担设置"])
self:CreateHUD();self:Select(self.page);self:Refresh()
end
function S:CreateHUD()
local hud=W:BackdropFrame(UIParent,.078,.094,.114,.94,.41,.79,.68,1)
hud:SetSize(350,234);hud:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-30,-150);hud:SetFrameStrata("HIGH")
hud:SetMovable(true);hud:EnableMouse(true);hud:RegisterForDrag("LeftButton")
hud:SetScript("OnDragStart",function()hud:StartMoving()end);hud:SetScript("OnDragStop",function()hud:StopMovingOrSizing()end)
self.hudFrame=hud;self.hudText=text(hud,"SFD · 测试模式",14,-14,322,13)
hud:Hide()
end
function S:Refresh()
if not self.frame then return end
local s=H:Snapshot()
self.status:SetText("状态："..STATUS[s.status]);self.time:SetText(clock(s.time).." / 06:30")
self.progress:SetWidth(math.max(.1,526*s.time/H.duration))
local nextText=clock(s.nextAt).." "..s.nextLabel
self.summary:SetText(H:Describe(s,false))
self.role:SetValue_(H.role);self.slot:SetValue_(H.slot);self.sender:SetChecked_(H.sender);self.fill:SetChecked_(H.autoFill)
self.hudFrame:SetShown(H.active and H.showHUD)
self.hudText:SetText("SFD · 测试模式\n\n"..H:Describe(s,true))
end
function S:Open(page)
self:HideLegacy()
self:Create();if page then self:Select(page)end
self.frame:Show();self:Refresh()
end
T:On("NOTIFY_EDIT_MODE_CHANGED",function(editing)
if not editing and S.anchorReopen then
S.anchorReopen=nil
if not InCombatLockdown()then S:Open("位置设置")end
end
end)
