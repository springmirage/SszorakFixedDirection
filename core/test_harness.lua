local T=unpack(SszorakFixedDirection)
local F=T.Fixed
local H={active=false,status="IDLE",elapsed=0,speed=1,role="RANGED_DPS",sender=false,slot="AUTO",showHUD=true,autoFill=true,timers={},trace={}}
T.TestHarness=H
H.duration=T.SFD_LOGICAL_TIMELINE_END
H.roles={MELEE_HEALER={"HEALER",65},TANK={"TANK",73},RANGED_DPS={"DAMAGER",62},RANGED_HEALER={"HEALER",256},HOLY_PALADIN={"HEALER",65},MISTWEAVER={"HEALER",270},MELEE={"DAMAGER",71}}
local AUTO={1,4,2,3,1,4}
local UI_KEYS={senderPos=true,panelPos=true,compassPos=true,senderScale=true,scale=true,compassSize=true,compassMarkerSize=true,compassAlpha=true,compassBossAlpha=true,senderAlpha=true,compassLocked=true,locked=true}
local function proxy(source,values)return setmetatable(values,{__index=source,__newindex=function(obj,key,value)
if UI_KEYS[key]then source[key]=value else rawset(obj,key,value)end
end})end
function H:Timer(delay,callback,interval)
local timer={at=self.elapsed+math.max(0,delay),callback=callback,interval=interval}
function timer:Cancel()self.cancelled=true end
self.timers[#self.timers+1]=timer
return timer
end
function H:Record(kind,value)
if not self.rebuilding then self.trace[#self.trace+1]={time=self.elapsed,kind=kind,value=value}end
end
function H:SelectRole(role)
if self.roles[role]then self.role=role end
end
function H:SetSender(on)
self.sender=on==true
if self.active then T.moduleMap.WindOctagon.db.senderShow=self.sender end
self:RefreshSender()
end
function H:SetSpeed(speed)
if speed==1 or speed==2 or speed==5 or speed==10 then self.speed=speed end
end
function H:RefreshSender()
if not self.senderOverlay then return end
local visible=self.active and self.sender
self.senderOverlay:SetShown(visible)
self.senderBase:SetShown(visible)
if visible then
self.senderBase:SetAlpha(1)
self.senderShield:SetShown(F.ready or(F.senderClicks or 0)>=3 or self.status~="RUNNING")
T.moduleMap.WindOctagon:SFDUpdateSenderStatus()
end
end
function H:AttachSender(base,dirs,positions,width,height)
self.senderBase=base
if not self.senderOverlay then
local overlay=CreateFrame("Frame",nil,base)
overlay:SetAllPoints(base);overlay:SetFrameLevel(base:GetFrameLevel()+30)
self.senderOverlay=overlay;self.senderButtons={}
for _,idx in ipairs(dirs)do
local marker=idx
local b=CreateFrame("Button",nil,overlay)
b:SetSize(48,48);b:SetPoint("CENTER",overlay,"CENTER",(positions[idx][1]-.5)*width,(.5-positions[idx][2])*height)
b:RegisterForClicks("AnyUp")
b:SetScript("OnClick",function()H:SendWind(marker)end)
local tex=b:CreateTexture(nil,"HIGHLIGHT");tex:SetAllPoints();tex:SetColorTexture(.4,1,.7,.3)
self.senderButtons[idx]=b
end
local shield=CreateFrame("Button",nil,overlay)
shield:SetAllPoints();shield:SetFrameLevel(overlay:GetFrameLevel()+10)
shield:EnableMouse(true);shield:SetScript("OnClick",function()end)
self.senderShield=shield
end
self:RefreshSender()
end
function H:SendWind(index)
if not self.active or self.status~="RUNNING"or not self.sender or F.ready or(F.senderClicks or 0)>=3 then return false end
-- Index comes from a test button/binding, never from received chat.
if type(index)~="number"or index<1 or index>8 or index%1~=0 then return false end
F.senderClicks=(F.senderClicks or 0)+1
local token="w"..index
self.lastMockToken=token
T.moduleMap.WindOctagon:SFDTestReceive(token)
self:Record("local_send",token)
self:RefreshSender()
return true
end
function H:SeedMissing()
if not self.autoFill then return end
local samples={2,3,7}
for slot=1,3 do
-- Only test-generated ordinary tokens exist in this isolated receiver session.
if F.tokens[slot]==nil then
T.moduleMap.WindOctagon:SFDTestReceive("w"..samples[slot])
end
end
if F.ready then F.senderClicks=3 end
self:RefreshSender()
end
function H:Chosen(window)
local role=self.roles[self.role]
if not role or not F:Eligible(role[1],role[2])then return false end
if self.slot=="AUTO"then return AUTO[(window.round-1)*2+window.pair]==window.position end
return tonumber(self.slot)==window.position
end
function H:InjectWarning(window)
if not self.active then return end
F:Tick(self.elapsed)
if not self:Chosen(window)then return end
self:SeedMissing()
local accepted,shown,reason=T.moduleMap.OrbPositionAlert:SFDTestWarning(window.index)
self:Record("warning",{slot=window.position,accepted=accepted,shown=shown,reason=reason,anchor=F.bossAnchor})
end
function H:InstallContext()
local wind,orb=T.moduleMap.WindOctagon,T.moduleMap.OrbPositionAlert
self.saved={windDB=wind.db,orbDB=orb.db,playerInfo=F.PlayerInfo,say=F.Say,schedule=T.Notify.Schedule}
wind.db=proxy(wind.db,{senderShow=self.sender,compassEnabled=true,enabled=true})
orb.db=proxy(orb.db,{enabled=true,debug=false})
F.PlayerInfo=function()local r=H.roles[H.role];return r[1],r[2]end
F.Say=function(obj,text,tag,duration,voice)
H:Record("cue",text)
return H.saved.say(obj,text,tag,duration,voice)
end
T.Notify.Schedule=function(obj,config)
if H.rebuilding and config.channels then
local copy={};for k,v in pairs(config)do copy[k]=v end
copy.channels={TEXT=config.channels.TEXT,SERPENT_FURY=config.channels.SERPENT_FURY};config=copy
end
return H.saved.schedule(obj,config)
end
end
function H:Start()
if InCombatLockdown()or(F.active and not self.active)or self.realEncounter then
print("战斗进行中，无法启动测试。");return false
end
if self.active then self:Stop()end
if T.Notify.anchor and T.Notify.anchor:IsEditing()then T.Notify.anchor:ExitEditMode(true)end
self.elapsed=0;self.timers={};self.trace={};self.lastMockToken=nil;self.advancingTo=nil
self.active=true;self.status="RUNNING"
self:InstallContext()
F:Start(3420,16)
T.moduleMap.WindOctagon:SFDTestBegin()
-- Pin event boundaries to their source timestamps (avoid ticker rounding drift).
for _,event in ipairs(F.events)do
local item=event
self:Timer(item[1],function()
if item[2]=="pre"then H:SeedMissing()end
F:Tick(H.elapsed)
end)
end
-- Use the live module's original warning windows, not a second timetable.
for _,window in ipairs(T.moduleMap.OrbPositionAlert.WARNING_WINDOWS.M)do
local selected=window
self:Timer(window.at,function()H:InjectWarning(selected)end)
end
self:RefreshSender();self:RefreshUI()
return true
end
function H:Pause()
if self.active and self.status=="RUNNING"then self.status="PAUSED";self:RefreshSender();self:RefreshUI()end
end
function H:Resume()
if self.active and self.status=="PAUSED"then self.status="RUNNING";self:RefreshSender();self:RefreshUI()end
end
function H:Stop(completed)
self.advancingTo=nil
if self.active then
F:Stop()
for _,timer in ipairs(self.timers)do timer:Cancel()end
self.timers={}
local saved=self.saved
F.PlayerInfo=saved.playerInfo;F.Say=saved.say;T.Notify.Schedule=saved.schedule
T.moduleMap.WindOctagon.db=saved.windDB;T.moduleMap.OrbPositionAlert.db=saved.orbDB
self.active=false;self.saved=nil
if self.senderOverlay then self.senderOverlay:Hide();self.senderBase:Hide()end
T.moduleMap.WindOctagon:SFDTestEnd()
end
self.status=completed and"COMPLETED"or"IDLE"
self.elapsed=completed and self.duration or 0
self.lastMockToken=nil
self:RefreshUI()
end
function H:Restart()return self:Start()end
function H:AdvanceTo(target)
if not self.active then return end
target=math.min(self.duration,math.max(self.elapsed,target))
self.advancingTo=target
while self.active do
local earliest
for _,timer in ipairs(self.timers)do
if not timer.cancelled and timer.at<=target and(not earliest or timer.at<earliest.at)then earliest=timer end
end
if not earliest then break end
self.elapsed=earliest.at
if earliest.interval then earliest.at=earliest.at+earliest.interval else earliest.cancelled=true end
earliest.callback()
end
self.advancingTo=nil
if not self.active then return end
self.elapsed=target;F:Tick(target)
-- Discard cancelled one-shot timers; pause retains all pending timers.
local pending={};for _,timer in ipairs(self.timers)do if not timer.cancelled then pending[#pending+1]=timer end end
self.timers=pending
self:RefreshSender()
if target>=self.duration then self:Stop(true)end
end
function H:Step(realDelta)
if self.active and self.status=="RUNNING"then self:AdvanceTo(self.elapsed+realDelta*self.speed)end
self.uiElapsed=(self.uiElapsed or 0)+realDelta
if self.uiElapsed>=.1 then self.uiElapsed=0;self:RefreshUI()end
end
function H:Jump(value)
local seconds=value
if type(value)=="string"then
local m,s=value:match("^(%d+):(%d%d)$")
if not m or tonumber(s)>=60 then print("请输入分钟和秒，例如 02:20。");return false end
seconds=tonumber(m)*60+tonumber(s)
end
if type(seconds)~="number"or seconds<0 or seconds>self.duration then print("测试范围为00:00至06:30。");return false end
local paused=self.status=="PAUSED"
if not self:Start()then return false end
self.rebuilding=true
self:AdvanceTo(seconds)
self.rebuilding=false
if self.active then
-- Replaying the same timeline rebuilds state; no backlog of speech/animation.
F.bossMoving=false;F.animating=false;F.visualAngle=F.facingAnchor=="STAR"and 180 or 0
F:RenderRotation(F.visualAngle);F:PaintHighlights()
if paused then self:Pause()end
end
self:RefreshUI();return true
end
function H:NextEvent()
local best,label
for _,event in ipairs(F.events)do
if event[1]>self.elapsed and event[2]~="expire"and event[2]~="cycle"and event[2]~="pre"then
best=event[1];label=event[2]=="wind"and"看风"or event[2]=="rotate"and"罗盘转向星星"or("BOSS带到"..({MOON="月亮",STAR="星星",CENTER="中场"})[event[3]]);break
end
end
for _,window in ipairs(T.moduleMap.OrbPositionAlert.WARNING_WINDOWS.M)do
if self:Chosen(window)and window.at>self.elapsed and(not best or window.at<best)then best=window.at;label="模拟点名：第"..window.position.."个放球点" end
end
local serpent=T.moduleMap.SerpentFuryAlert
if serpent.db.enabled then
local at,text=serpent:NextEvent(self.elapsed)
if at and(not best or at<best)then best=at;label=text end
end
return best or self.duration,label or"测试结束"
end
function H:Snapshot()
local nextAt,nextLabel=self:NextEvent()
return{status=self.status,time=self.elapsed,speed=self.speed,role=self.role,sender=self.sender,slot=self.slot,
anchor=self.active and(F.bossAnchor and(F.compassState=="IDLE"and"CENTER"or F.bossAnchor)or"NONE")or"NONE",
lastAnchor=F.bossAnchor or"NONE",compass=F.compassState or"IDLE",cycle=F.cycle or 0,cyst=F.cystRound or"NONE",nextAt=nextAt,nextLabel=nextLabel}
end
function H:RefreshUI()if T.Settings then T.Settings:Refresh()end end
local ROLE_NAMES={TANK="坦克",RANGED_DPS="远程 DPS",RANGED_HEALER="远程治疗",MELEE_HEALER="近战治疗",HOLY_PALADIN="近战治疗",MISTWEAVER="近战治疗",MELEE="近战 DPS"}
local ANCHOR_NAMES={MOON="月亮",STAR="星星",CENTER="中场",NONE="未开始"}
local COMPASS_NAMES={MOON_UP="月亮朝上",STAR_UP="星星朝上",IDLE="待命"}
local ROUND_NAMES={NONE="暂无",FIRST="第一轮",SECOND="第二轮"}
local STATUS_NAMES={IDLE="未运行",RUNNING="运行中",PAUSED="暂停",COMPLETED="已完成"}
local function timeText(seconds)local n=math.floor(seconds or 0);return string.format("%02d:%02d",math.floor(n/60),n%60)end
function H:Describe(s,full)
local detail="BOSS位置："..ANCHOR_NAMES[s.anchor].."   罗盘："..COMPASS_NAMES[s.compass].."\n周期："..s.cycle.." / 3   囊肿："..ROUND_NAMES[s.cyst].."\n下一提醒："..timeText(s.nextAt).." "..s.nextLabel
if not full then return detail end
return "状态："..STATUS_NAMES[s.status].."\n时间："..timeText(s.time).." / 06:30（"..s.speed.."倍速）\n职责："..ROLE_NAMES[s.role].."\n发送端："..(s.sender and"开启"or"关闭").."\n放球位置："..(s.slot=="AUTO"and"自动轮换"or("第"..s.slot.."个放球点")).."\n"..detail
end
function H:PrintStatus()print("SFD 测试状态\n"..self:Describe(self:Snapshot(),true))end

local driver=CreateFrame("Frame")
driver:SetScript("OnUpdate",function(_,elapsed)H:Step(elapsed)end)
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("ENCOUNTER_START")
driver:RegisterEvent("ENCOUNTER_END")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent",function(_,event)
if event=="ENCOUNTER_START"then
H.realEncounter=true;if H.active then H:Stop()end
elseif event=="ENCOUNTER_END"then H.realEncounter=false
elseif H.active then
H:Stop()
if event=="PLAYER_REGEN_DISABLED"then print("进入战斗，SFD测试已停止。")end
end
end)
