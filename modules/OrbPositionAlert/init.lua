local T,_,L=unpack(SszorakFixedDirection)
local GetTime=T.RuntimeClock.GetTime
local mod=T:NewModule("OrbPositionAlert",L.orbpos_name)
mod._hideOptions=true
local TARGET_ENCOUNTER_ID=3420
local TEMPLATE_IDS={
H="builtin:dft_va_3420_generic_h_v1",
M="builtin:dft_va_3420_generic_m_v1",
}
local ALERT_SPELL_ID=1305963
local EXPECTED_OCCURRENCES=12
local OCCURRENCES_PER_ROUND=4
local WARNING_TOLERANCE=1.2
local WARNING_SEVERITY=2
local WARNING_DURATION=3.5
local WARNING_DURATION_TOLERANCE=0.1
local ALERT_TAG="sszorak_orb_position"
local COMPASS_ALERT_DURATION=10
local RAID_AURA_RULE_KEY="cystDrop"
local DEFAULTS={
enabled=true,
duration=11,
debug=false,
}
local MEDIA=T.addonPath.."media\\WindOctagon\\"
local MARKER_SIZE=40
local ALERT_FORMATS={
opposite=string.format(
L.orbpos_alert_format,
"|T"..MEDIA.."%s_o:"..MARKER_SIZE..":"..MARKER_SIZE.."|t",
"%s"),
}
local TEST_MARKERS={
[1]="w7",
[2]="w8",
[3]="w2",
[4]="w5",
}
mod.WARNING_WINDOWS={
H={},
M={},
}
mod.WINDOW_LOAD_ERRORS={}
local engaged=false
local debugActive=false
local difficulty
local fightStart
local markerTokens={}
local markerReady={}
local markerRound=0
local firedOccurrences={}
local personalAssignments={}
local pendingAssignment
local warningFrame
local function diagnostic(event,extra)
-- Snapshot ordinary readiness flags only. This observer cannot affect the caller.
pcall(function()
local data={markerRound=markerRound,
point1Present=markerReady[1]==true,point2Present=markerReady[2]==true,
point3Present=markerReady[3]==true,point4Present=markerReady[4]==true,
pointsReady=markerReady[1]==true and markerReady[2]==true and markerReady[3]==true and markerReady[4]==true}
for key,value in pairs(extra or{})do data[key]=value end
T:Diagnostic(event,data)
end)
end
local function cfg(key)
local value=mod.db and mod.db[key]
if value==nil then return DEFAULTS[key]end
return value
end
local function difficultyCode(value)
local numeric=tonumber(value)
if value=="H"or numeric==15 then return"H"end
if value=="M"or numeric==16 or numeric==233 then return"M"end
return nil
end
local function roundTenth(value)
return math.floor(value*10+0.5)/10
end
local function matchesExpected(actual,expected,tolerance)
if actual==nil then return false end
return math.abs(actual-expected)<=(tolerance or 0)
end
function mod.BuildWarningWindows(template)
if type(template)~="table"then return nil,"missing_template"end
local category
for _,candidate in ipairs(template.spellReminders or{})do
if tonumber(candidate.spellId)==ALERT_SPELL_ID
and type(candidate.times)=="table"
then
category=candidate
break
end
end
if not category then return nil,"missing_category"end
if#category.times~=EXPECTED_OCCURRENCES then
return nil,"unexpected_count_"..tostring(#category.times)
end
local occurrences={}
for index,occurrence in ipairs(category.times)do
local at=tonumber(occurrence.time)
if not at or tonumber(occurrence.phaseNumber or 1)~=1 then
return nil,"invalid_occurrence"
end
occurrences[index]={
id=occurrence.id,
at=roundTenth(at),
}
end
table.sort(occurrences,function(left,right)return left.at<right.at end)
local windows={}
for index,occurrence in ipairs(occurrences)do
local position=((index-1)%OCCURRENCES_PER_ROUND)+1
local round=math.floor((index-1)/OCCURRENCES_PER_ROUND)+1
windows[index]={
key=occurrence.id or("occurrence_"..index),
index=index,
round=round,
position=position,
pair=position<=2 and 1 or 2,
at=occurrence.at,
tolerance=WARNING_TOLERANCE,
assignment={slot=position,mode="opposite"},
}
end
for index,window in ipairs(windows)do
local previous=windows[index-1]
local following=windows[index+1]
window.from=window.at-window.tolerance
window.to=window.at+window.tolerance
if previous then
window.from=math.max(
window.from,(previous.at+window.at)/2)
end
if following then
local midpoint=(window.at+following.at)/2
if midpoint<window.to then
window.to=midpoint
window.upperExclusive=true
end
end
end
return windows
end
function mod:ReloadWarningWindows()
local loaded,errors={},{}
for _,diff in ipairs({"H","M"})do
local request={
encounterID=TARGET_ENCOUNTER_ID,
templateID=TEMPLATE_IDS[diff],
}
T:Fire("BOSSMOD_QUERY_TEMPLATE",request)
local windows,err=self.BuildWarningWindows(request.template)
if windows then
self.WARNING_WINDOWS[diff]=windows
loaded[diff]=true
else
self.WARNING_WINDOWS[diff]={}
errors[diff]=err
end
end
self.WINDOW_LOAD_ERRORS=errors
return loaded,errors
end
function mod:ClassifyWarning(diff,elapsed,severity,duration)
local windows=self.WARNING_WINDOWS[difficultyCode(diff)]
if type(windows)~="table"or type(elapsed)~="number"then return nil end
if not matchesExpected(severity,WARNING_SEVERITY,0)
or not matchesExpected(duration,WARNING_DURATION,WARNING_DURATION_TOLERANCE)
then
return nil
end
for _,window in ipairs(windows)do
local beforeEnd=elapsed<window.to
or(not window.upperExclusive and elapsed<=window.to)
if elapsed>=window.from and beforeEnd
then
return window
end
end
return nil
end
function mod:DescribeWarningMatch(diff,severity,duration,window)
if not matchesExpected(severity,WARNING_SEVERITY,0)
or not matchesExpected(duration,WARNING_DURATION,WARNING_DURATION_TOLERANCE)
then
return L.orbpos_debug_miss_signature
end
local code=difficultyCode(diff)
local windows=code and self.WARNING_WINDOWS[code]or nil
if type(windows)~="table"or#windows==0 then
return string.format(
L.orbpos_debug_miss_schedule,tostring(code or diff or"?"))
end
if not window then return L.orbpos_debug_miss_time end
return string.format(
L.orbpos_debug_hit,
window.index,window.round,window.position,
window.at,window.from,window.to)
end
local function printWarningDebug(elapsed,diff,severity,duration,window)
local severityText=severity and string.format("%.0f",severity)or"nil"
local durationText=duration and string.format("%.3f",duration)or"nil"
local result=mod:DescribeWarningMatch(diff,severity,duration,window)
print("|cff66ddff[SszorakFixedDirection/"..L.orbpos_name.."]|r "
..string.format(
L.orbpos_debug_line,
elapsed,tostring(diff or"?"),
severityText,durationText,result))
end
local function clearMarkers(reason)
markerTokens={}
markerReady={}
diagnostic("POINT_SET_RESET",{resetReason=reason or"GROUP_CLEARED"})
if T.Notify and T.Notify.CancelByTag then
T.Notify:CancelByTag(ALERT_TAG)
end
T:Fire("ORB_POSITION_ALERT_COMPASS_HIDE")
end
local function startMarkerRound()
markerRound=markerRound+1
clearMarkers("MARKER_ROUND_START")
end
local function fireTextAlert(window,markerToken,modeOverride)
local shown=T.Fixed:Assignment(window,markerToken,modeOverride,cfg("duration"))
if shown then diagnostic("ASSIGNMENT_ACCEPTED",{assignmentAccepted=true,slot=window.assignment.slot})
else diagnostic("ASSIGNMENT_REJECTED",{assignmentRejected=true,rejectReason="NOTIFY_UNAVAILABLE",slot=window.assignment.slot})end
return shown
end
local function showAssignment(window,debugIndex)
if not cfg("enabled")then return false end
local assignment=window.assignment
if assignment.mode~="free"
and(markerRound<window.round or not markerReady[assignment.slot])
then
pendingAssignment={
window=window,
debugIndex=debugIndex,
}
diagnostic("ASSIGNMENT_REJECTED",{assignmentRejected=true,rejectReason="POINTS_NOT_READY",slot=assignment.slot})
return false,"waiting_marker"
end
local markerToken=markerTokens[assignment.slot]
pendingAssignment=nil
return fireTextAlert(window,markerToken)
end
local function onMarkerReceived(sequence,markerToken)
local slot=tonumber(sequence)
if not slot or slot<1 or slot>4 then return end
markerTokens[slot]=markerToken
markerReady[slot]=true
diagnostic(slot==4 and"POINT4_SYNTHESIZED"or("POINT"..slot.."_RECEIVED"),
{slot=slot,point4Anchor=slot==4 and T.Fixed.bossAnchor or nil})
if markerReady[1]and markerReady[2]and markerReady[3]and markerReady[4]then
diagnostic("POINT_SET_READY")
end
local pending=pendingAssignment
if pending and pending.window.assignment.slot==slot then
local shown=showAssignment(pending.window,pending.debugIndex)
if shown and pending.debugIndex then
T:Fire("DEBUG_SSZORAK_TEST_WARNING_RESULT",
pending.debugIndex,true,true,pending.window,true)
end
end
end
local function clearMarkerGroup()
local pending=pendingAssignment
pendingAssignment=nil
clearMarkers("GROUP_CLEARED")
if pending and pending.debugIndex then
T:Fire("DEBUG_SSZORAK_TEST_WARNING_RESULT",
pending.debugIndex,false,false,pending.window,
false,"group_cleared")
end
end
local function startEncounter(encounterID,encounterDifficulty,startedAt)
if tonumber(encounterID)~=TARGET_ENCOUNTER_ID or not T.Fixed:IsMythic(encounterDifficulty)then return end
if engaged and difficulty==difficultyCode(encounterDifficulty)then return end
engaged=true
difficulty=difficultyCode(encounterDifficulty)
fightStart=tonumber(startedAt)or GetTime()
markerRound=0
firedOccurrences={}
personalAssignments={}
pendingAssignment=nil
clearMarkers("ENCOUNTER_START")
end
local function stopEncounter(encounterID)
if encounterID and tonumber(encounterID)~=TARGET_ENCOUNTER_ID then return end
engaged=false
difficulty=nil
fightStart=nil
markerRound=0
firedOccurrences={}
personalAssignments={}
pendingAssignment=nil
clearMarkers("ENCOUNTER_END")
end
function mod:OnWarning(info,debugIndex)
T:DiagnosticCall("Warning")
diagnostic("WARNING_CALLBACK_ENTER",{warningReceived=true})
if debugActive and debugIndex==nil then
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="TEST_ISOLATION"})
return false,false,"real_warning_ignored"
end
if not(engaged and fightStart and type(info)=="table")then
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="NOT_ENGAGED"})
return false,false,"not_engaged"
end
local elapsed=GetTime()-fightStart
-- Legacy genuinely needs these two fields. Never guess a signature from time alone.
if T.Fixed:IsOpaque(info.severity)or T.Fixed:IsOpaque(info.duration)then
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="SECRET_CLASSIFICATION_FIELDS"})
return false,false,"restricted_warning"
end
local severity=tonumber(info.severity)
local duration=tonumber(info.duration)
local window=self:ClassifyWarning(
difficulty,elapsed,severity,duration)
if window then
T:DiagnosticCall("BindWindow",window.key)
diagnostic("WINDOW_MATCH",{matchedWindow=true,windowName="P"..window.position,windowIndex=window.index,slot=window.assignment.slot})
diagnostic("SLOT_SELECTED",{slot=window.assignment.slot,windowName="P"..window.position,windowIndex=window.index})
elseif matchesExpected(severity,WARNING_SEVERITY,0)and matchesExpected(duration,WARNING_DURATION,WARNING_DURATION_TOLERANCE)then
diagnostic("WINDOW_NONE",{matchedWindow=false,rejectReason="NO_WINDOW"})
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="NO_WINDOW"})
else
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="SIGNATURE_MISMATCH"})
end
if cfg("debug")then
printWarningDebug(elapsed,difficulty,severity,duration,window)
end
if not cfg("enabled")then
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="DISABLED"})
return false,false,"disabled",window,elapsed
end
if not window then
return false,false,"outside_window",nil,elapsed
end
if debugIndex~=nil and window.index~=debugIndex then
diagnostic("WARNING_REJECTED",{warningRejected=true,rejectReason="UNEXPECTED_TEST_WINDOW"})
return false,false,"unexpected_window",window,elapsed
end
local accepted,shown,reason=
self:ApplyWarningWindow(window,debugIndex)
diagnostic(accepted and"WARNING_ACCEPTED"or"WARNING_REJECTED",{
warningAccepted=accepted==true,warningRejected=accepted~=true,
rejectReason=not accepted and(reason=="duplicate"and"DUPLICATE"or reason=="assignment_locked"and"ASSIGNMENT_LOCKED"or"UNKNOWN")or nil,
slot=window.assignment.slot})
return accepted,shown,reason,window,elapsed
end
function mod:ApplyWarningWindow(window,debugIndex)
if not engaged then return false,false,"not_engaged"end
if not cfg("enabled")then return false,false,"disabled"end
if type(window)~="table"then return false,false,"missing_window"end
local pairKey=(window.round-1)*2+window.pair
local assigned=personalAssignments[pairKey]
if assigned and assigned~=window.key then
return false,false,"assignment_locked"
end
if firedOccurrences[window.key]then
local pending=pendingAssignment
if pending and pending.window.key==window.key then
local shown,resolution=showAssignment(window,debugIndex)
return true,shown,resolution or"waiting_marker"
end
return false,false,"duplicate"
end
personalAssignments[pairKey]=window.key
firedOccurrences[window.key]=true
local shown,resolution=showAssignment(window,debugIndex)
return true,shown,resolution
end
function mod:ShowTest(order)
local slot=tonumber(order)
local markerToken=TEST_MARKERS[slot]
if not markerToken then return false end
return fireTextAlert({
index=slot,
assignment={slot=slot,mode="opposite"},
},markerToken)
end
function mod:SFDTestWarning(index)
if not(T.TestHarness and T.TestHarness.active)then return false end
return self:OnWarning({severity=WARNING_SEVERITY,duration=WARNING_DURATION},index)
end
local function setConfig(key,value)
if not mod.db then return end
if key=="enabled"then
mod.db.enabled=value and true or false
if mod.db.enabled then
mod:EnsureRuntime();mod:ReloadWarningWindows()
else
local pending=pendingAssignment
pendingAssignment=nil
if pending and pending.debugIndex then
T:Fire("DEBUG_SSZORAK_TEST_WARNING_RESULT",
pending.debugIndex,false,false,pending.window,false,"disabled")
end
if T.Notify and T.Notify.CancelByTag then
T.Notify:CancelByTag(ALERT_TAG)
end
T:Fire("ORB_POSITION_ALERT_COMPASS_HIDE")
end
elseif key=="debug"then
mod.db.debug=value and true or false
elseif key=="duration"then
local duration=tonumber(value)
if duration then mod.db.duration=math.max(3,math.min(20,duration))end
end
end
function mod:OnLogin()
self:EnsureRuntime();self:ReloadWarningWindows()
T:Fire("RAIDAURAWATCH_SET_SLOT_TEXTURES",RAID_AURA_RULE_KEY,nil)
end
function mod:OnInit()
self:EnsureRuntime()
if(self.db.schemaVersion or 0)<1 then
if self.db.duration==10 then self.db.duration=11 end
self.db.schemaVersion=1
end
if self.db.schemaVersion<2 then
self.db.debug=false
self.db.schemaVersion=2
end
for key,value in pairs(DEFAULTS)do
if self.db[key]==nil then self.db[key]=value end
end
local loaded,errors=self:ReloadWarningWindows()
if not loaded.M then
print("|cffff4444SszorakFixedDirection/OrbPositionAlert|r "
..string.format(
L.orbpos_template_error,"M",tostring(errors.M)))
end
end
function mod:EnsureRuntime()
if not warningFrame then warningFrame=CreateFrame("Frame")end
warningFrame:RegisterEvent("ENCOUNTER_WARNING")
warningFrame:SetScript("OnEvent",function(_,_,info)
if T.TestHarness and T.TestHarness.active then return end
self:OnWarning(info)
end)
-- Standalone startup.lua already owns direct encounter events.
if self._runtimeSubscribed then return end
self._runtimeSubscribed=true
T:On("BOSS_ENGAGED",startEncounter)
T:On("BOSS_DISENGAGED",stopEncounter)
T:On("WIND_OCTAGON_ROUND_RESET",startMarkerRound)
T:On("WIND_OCTAGON_GROUP_CLEARED",clearMarkerGroup)
T:On("WIND_OCTAGON_MARKER_RECEIVED",onMarkerReceived)
T:On("SFD_POINT4",function(token)onMarkerReceived(4,token)end)
T:On("BOSSMOD_TEMPLATES_CHANGED",function(encounterID)
if tonumber(encounterID)==TARGET_ENCOUNTER_ID then
self:ReloadWarningWindows()
end
end)
T:On("ORB_POSITION_ALERT_CONFIG_QUERY",function(state)
state.enabled=cfg("enabled")
state.duration=cfg("duration")
state.debug=cfg("debug")
end)
T:On("ORB_POSITION_ALERT_CONFIG_SET",setConfig)
T:On("ORB_POSITION_ALERT_TEST",function(order)self:ShowTest(order)end)
end
