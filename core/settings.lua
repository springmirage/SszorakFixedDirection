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
for i,name in ipairs({"常规","位置设置","测试","版本检测"})do
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
self:CreateVersionPage();self:CreateHUD();self:Select(self.page);self:Refresh()
end
function S:CreateVersionPage()
local p=self.pages["版本检测"]
text(p,"版本检测",24,-22,510,20)
text(p,"本机检测基准："..T.version,24,-52,510,13)
self.versionButton=button(p,"检测版本",24,-78,150,function()T.VersionCheck:StartScan()end)
self.versionSummary=text(p,"点击检测版本，查询当前队伍或团队。",24,-118,526,12)
text(p,"角色名（服务器）",24,-175,190,13);text(p,"在线状态",218,-175,62,12)
text(p,"检测版本",284,-175,82,12);text(p,"版本判断",370,-175,158,12)
local scroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",24,-200);scroll:SetSize(504,266)
local content=CreateFrame("Frame",nil,scroll);content:SetSize(504,1760);scroll:SetScrollChild(content)
self.versionContent=content
self.versionRows={}
for i=1,40 do
local y=-(i-1)*44
self.versionRows[i]={name=text(content,"",0,y,190,12),online=text(content,"",194,y,62,12),
version=text(content,"",260,y,82,12),status=text(content,"",346,y,158,12)}
for _,fs in pairs(self.versionRows[i])do fs:SetHeight(40)end
local rowIndex=i
local hit=CreateFrame("Frame",nil,content);hit:SetPoint("TOPLEFT",0,y);hit:SetSize(504,42);hit:EnableMouse(true)
hit:SetScript("OnEnter",function(owner)
local row=T.VersionCheck.rows[rowIndex]
if not row then return end
GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
GameTooltip:AddLine(row.name:gsub("|","||"))
GameTooltip:AddLine(row.connection or"")
GameTooltip:AddLine("版本："..(row.version and row.version:gsub("|","||")or"未检测到"))
GameTooltip:AddLine(row.version and("已加载 · "..row.judgment)or row.state)
GameTooltip:Show()
end)
hit:SetScript("OnLeave",function()GameTooltip:Hide()end)
end
text(p,"未响应：可能未安装、未启用、旧版无回报能力或通信失败。\n版本仅与本机基准比较，不代表官方最新版。",24,-484,526,12)
T.VersionCheck.onChanged=function()S:RefreshVersions()end
self:RefreshVersions()
end
function S:RefreshVersions()
if not self.versionRows then return end
local v=T.VersionCheck
local loaded,missing,outdated=0,0,0
for i,widgets in ipairs(self.versionRows)do
local row=v.rows[i]
widgets.name:SetText(row and row.name:gsub("|","||")or"")
widgets.online:SetText(row and row.connection or"")
widgets.version:SetText(row and(row.version and row.version:gsub("|","||")or"—")or"")
widgets.status:SetText(row and(row.version and("已加载\n"..row.judgment)or row.state)or"")
local classColor=row and RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class]
widgets.name:SetTextColor(classColor and classColor.r or .89,classColor and classColor.g or .92,classColor and classColor.b or .95)
local color=row and row.version and(row.judgment=="与本机一致"and{.3,.9,.4}or{1,.75,.3})or{.7,.7,.7}
widgets.status:SetTextColor(unpack(color))
if row then
if row.version then loaded=loaded+1;if row.judgment=="需要更新"then outdated=outdated+1 end
elseif row.online and not row.departed then missing=missing+1 end
end
end
self.versionContent:SetHeight(math.max(266,#v.rows*44))
self.versionButton:SetEnabled(not v.scanning)
self.versionButton:SetText_(v.scanning and("检测中（"..(v.remaining or 5).."秒）")or"检测版本")
self.versionButton.label:SetTextColor(v.scanning and .5 or .89,v.scanning and .5 or .92,v.scanning and .5 or .95)
local state=v.message or(#v.rows==0 and"点击检测版本，查询当前队伍或团队。"or
string.format("%s · 已加载 %d/%d · 需要更新 %d · %s %d",v.scanning and("检测中，剩余"..(v.remaining or 5).."秒")or"检测完成",loaded,#v.rows,outdated,v.scanning and"等待回报"or"未响应",missing))
if(v.newcomers or 0)>0 then state=state.."\n新加入"..v.newcomers.."人，请下次检测。"end
self.versionSummary:SetText(state)
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
