local T=unpack(SszorakFixedDirection)
-- Write-only observer. Never pass warning payloads, aura values or marker tokens here.
local D={enabled=true,MAX_FIGHTS=10,MAX_EVENTS_PER_FIGHT=300}
T.Diagnostics=D
local fields={eventType=true,encounterElapsed=true,localGetTime=true,cycle=true,round=true,
bossAnchor=true,compassState=true,markerRound=true,warningReceived=true,warningAccepted=true,
warningRejected=true,matchedWindow=true,windowName=true,windowIndex=true,slot=true,
pointsReady=true,point1Present=true,point2Present=true,point3Present=true,point4Present=true,
assignmentEntered=true,assignmentAccepted=true,assignmentRejected=true,assignmentShown=true,
assignmentCleared=true,rejectReason=true,resetReason=true,point4Anchor=true,source=true,
warningSequence=true,assignmentSequence=true,previousSlot=true,newSlot=true,
previousAssignmentSequence=true,newAssignmentSequence=true,previousWarningSequence=true,
newWarningSequence=true,previousShownAt=true,newShownAt=true,deltaSeconds=true,replacementReason=true}
local function scalar(value)
if issecretvalue and issecretvalue(value)then return nil end
local kind=type(value)
if kind=="string"then return value:sub(1,160)end
if kind=="boolean"then return value end
if kind=="number"and value==value and value~=math.huge and value~=-math.huge then return value end
end
local function copyFields(target,source)
for key in pairs(fields)do
local value=scalar(source[key])
if value~=nil then target[key]=value end
end
end
function D:Init()
local db=SszorakFixedDirectionDB
if type(db.diagnostics)~="table"then db.diagnostics={}end
local data=db.diagnostics
data.schemaVersion=1
if type(data.fights)~="table"then data.fights={}end
data.sequence=type(data.sequence)=="number"and data.sequence or 0
while #data.fights>self.MAX_FIGHTS do table.remove(data.fights,1)end
for _,fight in ipairs(data.fights)do
if type(fight.events)~="table"then fight.events={}end
while #fight.events>self.MAX_EVENTS_PER_FIGHT do table.remove(fight.events,1)end
end
self.data=data
end
function D:Begin(encounterID,difficultyID,startedAt)
if not self.enabled then return end
if not self.data then self:Init()end
local data=self.data
data.sequence=data.sequence+1
local stamp=time and time()or 0
local source=T.TestHarness and T.TestHarness.active and"TEST"or"RAID"
local fight={fightSessionId=string.format("%s-%s-%d",stamp,source,data.sequence),
addonVersion=T.version,timestamp=stamp,encounterId=encounterID,difficultyId=difficultyID,
fightStartLocalTime=GetTime(),source=source,events={},droppedEvents=0}
data.fights[#data.fights+1]=fight
while #data.fights>self.MAX_FIGHTS do table.remove(data.fights,1)end
self.current=fight;self.startedAt=startedAt;self.pointState={}
self.localWarningSequence=0;self.assignmentSequence=0;self.windowWarnings={}
self.attempt=nil;self.shown=nil;self.replacing=nil
self:Record("ENCOUNTER_START")
end
function D:Record(eventType,extra)
if not self.enabled or not self.current then return end
local f=T.Fixed or{}
local event={eventType=eventType,localGetTime=GetTime(),source=self.current.source,
warningSequence=self.localWarningSequence or 0,assignmentSequence=self.assignmentSequence or 0,
encounterElapsed=T.RuntimeClock.GetTime()-self.startedAt,
cycle=f.cycle or 0,round=f.cystRound or"NONE",bossAnchor=f.bossAnchor or"NONE",
compassState=f.compassState or"IDLE"}
if f.assignment then event.slot=f.assignment.slot;event.windowIndex=f.assignment.windowIndex end
if eventType:sub(1,11)=="ASSIGNMENT_"and self.attempt then
event.warningSequence=self.attempt.warningSequence
event.assignmentSequence=self.attempt.assignmentSequence
end
copyFields(event,self.pointState or{})
if extra then copyFields(event,extra)end
if extra and extra.point1Present~=nil then
self.pointState={}
for _,key in ipairs({"pointsReady","point1Present","point2Present","point3Present","point4Present","markerRound"})do
self.pointState[key]=event[key]
end
end
local events=self.current.events
if #events>=self.MAX_EVENTS_PER_FIGHT then
table.remove(events,1);self.current.droppedEvents=self.current.droppedEvents+1
end
events[#events+1]=event
end
function D:Warning()
if not self.enabled or not self.current then return end
self.localWarningSequence=(self.localWarningSequence or 0)+1
end
function D:BindWindow(key)
if not self.enabled or not self.current then return end
self.windowWarnings[key]=self.localWarningSequence
end
function D:Assignment(key,slot)
if not self.enabled or not self.current then return end
self.assignmentSequence=(self.assignmentSequence or 0)+1
self.attempt={slot=slot,assignmentSequence=self.assignmentSequence,
warningSequence=(key and self.windowWarnings[key])or self.localWarningSequence}
self:Record("ASSIGNMENT_ENTER",{assignmentEntered=true,slot=slot})
end
function D:PrepareShow()
if not self.enabled or not self.current then return end
-- Captured before Notify releases the previous frame. Observer state only.
self.replacing=self.shown
end
function D:Shown()
if not self.enabled or not self.current or not self.attempt then return end
local now=T.RuntimeClock.GetTime()-self.startedAt
local a=self.attempt
local previous=self.replacing
local current={slot=a.slot,assignmentSequence=a.assignmentSequence,
warningSequence=a.warningSequence,shownAt=now}
self.shown=current;self.replacing=nil
if previous then
local reason="UNKNOWN"
if previous.warningSequence>0 and current.warningSequence>0 then
reason=previous.warningSequence==current.warningSequence and"SAME_WARNING_REENTRY"or"NEW_WARNING_ASSIGNMENT"
end
self:Record("ASSIGNMENT_REPLACED",{
previousSlot=previous.slot,newSlot=current.slot,
previousAssignmentSequence=previous.assignmentSequence,newAssignmentSequence=current.assignmentSequence,
previousWarningSequence=previous.warningSequence,newWarningSequence=current.warningSequence,
previousShownAt=previous.shownAt,newShownAt=now,deltaSeconds=now-previous.shownAt,
replacementReason=reason})
end
self:Record("ASSIGNMENT_SHOWN",{assignmentShown=true,slot=current.slot})
end
function D:Cleared(reason)
if not self.enabled or not self.current then return end
local a=self.shown
self:Record("ASSIGNMENT_CLEARED",{assignmentCleared=true,resetReason=reason or"CANCELLED",
slot=a and a.slot,assignmentSequence=a and a.assignmentSequence,warningSequence=a and a.warningSequence})
self.shown=nil
end
function D:Finish(reason)
if not self.current then return end
self:Record("ENCOUNTER_END",{resetReason=reason})
self.current.ended=true;self.current.endLocalTime=GetTime();self.current.endReason=reason
self.current=nil;self.pointState=nil;self.shown=nil;self.replacing=nil;self.attempt=nil
end
function D:Clear()
SszorakFixedDirectionDB.diagnostics={schemaVersion=1,sequence=0,fights={}}
self.data=SszorakFixedDirectionDB.diagnostics;self.current=nil;self.pointState=nil;self.shown=nil;self.replacing=nil;self.attempt=nil
print("SFD：诊断记录已清空。")
end
function D:Status()
if not self.data then self:Init()end
local fights=self.data.fights;local last=fights[#fights]
print("SFD 诊断 · 场次 "..#fights.." · 最近 "..(last and last.fightSessionId or"无")
.." · 事件 "..(last and #last.events or 0).." · 版本 "..T.version)
end
-- All diagnostic work, including context reads and storage, stays inside pcall.
-- Errors are deliberately discarded: even error text might contain restricted data.
function T:Diagnostic(eventType,extra)pcall(D.Record,D,eventType,extra)end
function T:DiagnosticCall(action,...)pcall(function(...)D[action](D,...)end,...)end
