local T=unpack(SszorakFixedDirection)
local mod=T:NewModule("SessionLog","战斗日志")
local D={MAX_FIGHTS=100,MAX_EVENTS_PER_FIGHT=300}
T.SessionLog=D
local frame=CreateFrame("Frame")
local function scalar(v)
if issecretvalue and issecretvalue(v)then return nil end
local k=type(v)
if k=="string"then return v:sub(1,160)end
if k=="boolean"then return v end
if k=="number"and v==v and v>-math.huge and v<math.huge then return v end
end
local fields={slot=true,cycle=true,round=true,bossAnchor=true,compassState=true,reason=true,tag=true,
point1Ready=true,point2Ready=true,point3Ready=true,point4Ready=true,assigned=true,success=true,markerSlot=true}
function D:Init()
local db=SszorakFixedDirectionDB
if type(db.sessionLogs)~="table"then db.sessionLogs={}end
local data=db.sessionLogs
data.schemaVersion=1
if type(data.raid)~="table"then data.raid={}end
if type(data.test)~="table"then data.test={}end
if type(data.sequence)~="number"then data.sequence=0 end
if not data.legacyIndexed then
local old=db.diagnostics
for _,f in ipairs(type(old)=="table"and type(old.fights)=="table"and old.fights or{})do
local copy={};for k,v in pairs(f)do copy[k]=v end
local list=f.source=="TEST"and data.test or data.raid
list[#list+1]=copy
end
data.legacyIndexed=true
end
self.data=data
end
function D:Record(kind,extra)
if not self.current then return end
local event={eventType=kind,localGetTime=GetTime(),encounterElapsed=T.RuntimeClock.GetTime()-self.startedAt,source=self.current.source}
for k in pairs(fields)do local value=extra and scalar(extra[k]);if value~=nil then event[k]=value end end
local events=self.current.events
if #events>=self.MAX_EVENTS_PER_FIGHT then table.remove(events,1);self.current.droppedEvents=self.current.droppedEvents+1 end
events[#events+1]=event
end
function D:SafeRecord(kind,extra)pcall(self.Record,self,kind,extra)end
function D:Begin(id,difficulty,at)
if id~=3420 or not T.Fixed:IsMythic(difficulty)then return end
if not self.data then self:Init()end
self.data.sequence=self.data.sequence+1
local source=T.TestHarness and T.TestHarness.active and"TEST"or"RAID"
local list=source=="TEST"and self.data.test or self.data.raid
local stamp=time and time()or 0
local f={fightSessionId=tostring(stamp).."-"..source.."-"..self.data.sequence,addonVersion=T.version,timestamp=stamp,source=source,encounterId=id,difficultyId=difficulty,events={},droppedEvents=0,settings={times={},energy={}}}
local serpent=T.moduleMap.SerpentFuryAlert
for i=1,6 do f.settings.times[i]=serpent.WAVES[i];f.settings.energy[i]=serpent.TARGET_ENERGY[i]end
list[#list+1]=f
while #list>self.MAX_FIGHTS do table.remove(list,1)end
self.current=f;self.startedAt=at or T.RuntimeClock.GetTime();self.previousState=nil
self:Record("ENCOUNTER_START")
end
function D:State()
if not self.current then return end
local f=T.Fixed;local a=f.assignment
local state={cycle=f.cycle,round=f.cystRound,bossAnchor=f.bossAnchor,compassState=f.compassState,assigned=a~=nil,slot=a and a.slot,
point1Ready=f.tokenReady[1]==true,point2Ready=f.tokenReady[2]==true,point3Ready=f.tokenReady[3]==true,point4Ready=f.tokenReady[4]==true}
local different=not self.previousState
for k in pairs(fields)do if not self.previousState or state[k]~=self.previousState[k]then different=true end end
if different then self:Record("STATE_CHANGED",state);self.previousState=state end
end
function D:Finish()
if not self.current then return end
self:SafeRecord("SESSION_END")
self.current.ended=true;self.current.endLocalTime=GetTime();self.current=nil;self.previousState=nil
end
function D:Status()
if not self.data then self:Init()end
print("SFD 日志：实战 "..#self.data.raid.."/100，测试 "..#self.data.test.."/100；旧事故记录保留。")
end
function mod:OnInit()
pcall(D.Init,D)
T:On("BOSS_ENGAGED",function(...)pcall(D.Begin,D,...)end)
T:On("BOSS_DISENGAGED",function()pcall(D.Finish,D)end)
T:On("SFD_TIMELINE_TICK",function()pcall(D.State,D)end)
T:On("WIND_OCTAGON_MARKER_RECEIVED",function(slot)D:SafeRecord("MARKER_RECEIVED",{markerSlot=slot})end)
frame:RegisterEvent("ENCOUNTER_WARNING");frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent",function(_,event,id,_,_,_,success)
if event=="ENCOUNTER_WARNING"then D:SafeRecord("WARNING_EVENT")
elseif id==3420 then D:SafeRecord("ENCOUNTER_END_EVENT",{success=success})end
end)
if hooksecurefunc then
hooksecurefunc(T.moduleMap.OrbPositionAlert,"OnWarning",function()D:SafeRecord("WARNING_PROCESSED");pcall(D.State,D)end)
hooksecurefunc(T.Notify,"Schedule",function(_,config)D:SafeRecord("NOTIFY_REQUEST",{tag=config.tag or config.id})end)
hooksecurefunc(T.Notify,"CancelByTag",function(_,tag)D:SafeRecord("NOTIFY_CANCEL",{tag=tag})end)
hooksecurefunc(T.Notify,"CancelAll",function()D:SafeRecord("NOTIFY_CANCEL_ALL")end)
end
end
