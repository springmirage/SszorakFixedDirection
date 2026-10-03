local T,C,L=unpack(SszorakFixedDirection)
local GetTime=T.RuntimeClock.GetTime
local C_Timer=T.RuntimeClock
local F={active=false,points={},tokens={},tokenReady={},highlights={},timers={}}
T.Fixed=F
local Compass=T.WindOctagonCompass
-- Derived from legacy DEFAULT_MARKERS, with the common 14+45 offset removed.
local ORDER=Compass.DEFAULT_MARKERS
local ANGLES={};for slot,marker in ipairs(ORDER)do ANGLES[marker]=(slot-1)*45 end
-- Byte-identical legacy wN_o.tga -> wOpposite.tga pairs, verified at build time.
local OPPOSITE={[1]=5,[2]=6,[3]=4,[4]=3,[5]=1,[6]=2,[7]=8,[8]=7}
local NAMES={[1]="星星",[2]="大饼",[3]="紫菱",[4]="三角",[5]="月亮",[6]="方块",[7]="十字",[8]="骷髅"}
local CLOCK={[0]=12,[45]=2,[90]=3,[135]=4,[180]=6,[225]=8,[270]=9,[315]=10}
local RELATIVE={[0]="正前",[45]="右上",[90]="右",[135]="右下",[180]="正后",[225]="左下",[270]="左",[315]="左上"}
F.MarkerAngles=ANGLES;F.Opposite=OPPOSITE;F.MarkerNames=NAMES
-- Exact legacy ranged-DPS list: Timeline/board_sidebar.lua:90-99.
local RANGED_DPS_SPECS={
[62]=true,[63]=true,[64]=true,
[265]=true,[266]=true,[267]=true,
[253]=true,[254]=true,
[102]=true,[258]=true,[262]=true,[1467]=true,[1473]=true,
}
function F:IsMythic(value)return value==16 or value==233 or value=="M"end
function F:IsOpaque(value)return issecretvalue and issecretvalue(value)or false end
function F:Eligible(role,spec)
if role=="HEALER"then return spec~=65 and spec~=270 and spec~=0 end
return role=="DAMAGER"and RANGED_DPS_SPECS[spec]==true
end
function F:PlayerInfo()
local idx=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization()
local spec=idx and C_SpecializationInfo.GetSpecializationInfo(idx)or 0
local role=UnitGroupRolesAssigned("player")
if role=="NONE"and idx and GetSpecializationRole then role=GetSpecializationRole(idx)end
return role,spec
end
function F:Say(text,tag,duration,voice)
local channels={TEXT={text=text,duration=duration or 5}}
if voice~=false then channels.TTS={text=text}end
T.Notify:Schedule({id=tag,tag=tag,channels=channels})
end
function F:Point4Marker()
local anchor=self.bossAnchor=="CENTER"and self.secondAnchor or self.bossAnchor
if anchor=="MOON"then return 5 end
if anchor=="STAR"then return 1 end
return nil
end
function F:Point4Token()
local marker=self:Point4Marker()
return marker and("w"..OPPOSITE[marker])or nil
end
function F:CompleteMarkers()
self.ready=true
self:RefreshPoint4()
T.moduleMap.WindOctagon:SFDUpdateSenderStatus()
end
function F:RefreshPoint4()
local marker=self:Point4Marker()
if marker then
self.points[4]=marker
self.tokens[4]=self:Point4Token()
if self.ready then T:Fire("SFD_POINT4",self:Point4Token())end
end
self:PaintHighlights()
end
function F:Direction(marker,anchor)
local angle=ANGLES[marker]
if not angle then return nil end
angle=(angle+((anchor or self.facingAnchor)=="STAR"and 180 or 0))%360
return CLOCK[angle],RELATIVE[angle]
end
function F:TargetText(slot,marker)
local name=NAMES[marker];if not name then return nil end
if slot==4 then
return"去"..name.."放球 · BOSS脚下","去"..name.."放球，BOSS脚下"
end
end
function F:RefreshAssignment(voice)
local a=self.assignment;if not a then return end
local duration=math.max(0,a.expires-GetTime())
if duration<=0 then return end
a.presentationStart=a.presentationStart or GetTime()
T.Notify:Schedule({id="sfd_assignment",tag="sfd_assignment",channels={
TEXT={duration=duration,attention=true,attentionStart=a.presentationStart,renderText=function(fs)
if a.slot==4 then
fs:SetText("去|T"..T.addonPath.."media\\WindOctagon\\w"..OPPOSITE[a.marker].."_o:40:40|t放球 · BOSS脚下")
else
fs:SetFormattedText("去|T"..T.addonPath.."media\\WindOctagon\\%s_o:40:40|t放球",a.token)
end
end},TTS=voice and{text=a.slot==4 and("去"..NAMES[a.marker].."放球，BOSS脚下")or L.orbpos_alert_tts}or nil,
}})
end
function F:MissingAssignment(window)
local expiry=self:Expiry(window.assignment.slot,window.round)
if expiry<=GetTime()then return end
self.highlights={};self:PaintHighlights()
self:Say("放球点数据缺失","sfd_assignment",expiry-GetTime())
end
function F:Expiry(slot,cycle)
local row=self.expiries[cycle or self.cycle]
return self.startedAt+(row and row[slot]or(self.elapsed or 0)+15)
end
function F:Assignment(window,token,mode)
if not self.active then return false end
local slot=window.assignment.slot
local marker=slot==4 and self:Point4Marker()or nil
if slot==4 and not marker then self:MissingAssignment(window);return false end
local expires=self:Expiry(slot,window.round)
if expires<=GetTime()then return false end
self.assignment={slot=slot,marker=marker,token=token,expires=expires}
self.tokens[slot]=token
self.highlights=slot==4 and{[4]="HIGH"}or{}
self.prewarn=nil
T.Notify:CancelByTag("sfd_pre")
self:PaintHighlights()
self:RefreshAssignment(true)
T:Fire("ORB_POSITION_ALERT_COMPASS_SHOW",token,"opposite",expires-GetTime())
return true
end
function F:AttachCompass(f)
self.compass=f;f.sfdDirections={}
f.sfdBoss=f:CreateTexture(nil,"ARTWORK",nil,1)
f.sfdBoss:SetTexture(T.addonPath.."media\\BossLogo\\M5.tga")
for _,angle in ipairs({45,90,135,225,270,315})do
local label=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
f.sfdDirections[angle]=label
end
local ring=CreateFrame("Frame",nil,f,"BackdropTemplate")
ring:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=2})
ring:SetBackdropBorderColor(0.25,1,0.45,1)
ring:Hide();f.sfdPoint4=ring
end
function F:LayoutCompass(f,geometry)
self.geometry=geometry
local radius=geometry.markerRadius*math.sqrt(2)+34
for angle,label in pairs(f.sfdDirections)do
label:ClearAllPoints()
label:SetPoint("CENTER",f,"CENTER",math.sin(math.rad(angle))*radius,math.cos(math.rad(angle))*radius)
label:SetText(CLOCK[angle].."点 / "..RELATIVE[angle])
end
f.sfdPoint4:SetSize(geometry.markerSize*math.sqrt(2)+6,geometry.markerSize*math.sqrt(2)+6)
f.sfdPoint4:ClearAllPoints()
f.sfdPoint4:SetPoint("CENTER",f,"CENTER",0,geometry.markerRadius*math.sqrt(2))
if f.player then f.player:Hide()end -- Do not imply knowledge of the player's real facing.
self:RenderRotation(self.visualAngle or 0)
self:PaintHighlights()
end
function F:RenderRotation(degrees)
local f=self.compass;if not f then return end
-- This is a preset UI angle only, never a game-facing value.
for _,marker in ipairs(f.markers)do marker:SetRotation(-math.rad(degrees))end
self:RenderBossIcon()
end
-- Independent display state: CENTER must never replace the retained Point4 anchor.
-- A short UI transition illustrates the planned move; it is not live boss tracking.
function F:SetBossDisplayAnchor(anchor)
local previous=self.bossDisplayAnchor
self.bossDisplayAnchor=anchor
local destination=anchor=="MOON"and 1 or anchor=="STAR"and -1 or 0
self.bossMoveFrom=self.bossFieldY or destination
self.bossMoveTo=destination
self.bossMoveStarted=GetTime()
self.bossMoving=previous~=nil and self.bossMoveFrom~=destination
self:RenderBossIcon()
end
function F:RenderBossIcon()
local f=self.compass;local g=self.geometry
if not f or not f.sfdBoss or not g then return end
local y=self.bossMoveTo or 1
local t=self.bossMoving and math.min(1,math.max(0,(GetTime()-self.bossMoveStarted)/0.6))or 1
if t<1 then
local eased=t*t*(3-2*t)
y=self.bossMoveFrom+(y-self.bossMoveFrom)*eased
else self.bossMoving=false end
self.bossFieldY=y
local angle=math.rad(self.visualAngle or 0)
local radius=g.markerRadius*math.sqrt(2)
local icon=f.sfdBoss
icon:ClearAllPoints()
icon:SetPoint("CENTER",f,"CENTER",math.sin(angle)*radius*y,math.cos(angle)*radius*y)
-- Scale against the rendered marker plane; a fixed cap can hide the boss behind large markers.
local size=g.markerSize*math.sqrt(2)*1.4
icon:SetSize(size,size)
local db=T.moduleMap.WindOctagon.db
icon:SetAlpha(db and db.compassBossAlpha or 0.65)
-- At either end, facing remains in field coordinates and follows compass rotation.
local facing=0
if self.bossMoving then
facing=angle+(self.bossMoveTo<self.bossMoveFrom and math.pi or 0)
elseif self.bossDisplayAnchor=="STAR"then facing=angle+math.pi
elseif self.bossDisplayAnchor=="MOON"then facing=angle end
icon:SetRotation(-(facing%(2*math.pi)))
icon:Show()
end
function F:Animate(f,elapsed)
self:RenderBossIcon()
if not self.animating then return end
self.animationElapsed=self.animationElapsed+elapsed
local t=math.min(1,self.animationElapsed/0.6);local eased=t*t*(3-2*t)
self.visualAngle=self.fromAngle+(self.toAngle-self.fromAngle)*eased
self:RenderRotation(self.visualAngle)
if t==1 then self.animating=false;self.visualAngle=self.toAngle%360;self:PaintHighlights()end
end
function F:PaintHighlights()
local f=self.compass;if not f then return end
-- Only local Point4 has a known field position. Never inspect chat tokens here.
local ring=f.sfdPoint4;ring:Hide()
local level=self.highlights[4]
if level and self:Point4Marker()then
ring:SetAlpha(self.animating and 0 or(level=="HIGH"and 1 or 0.28));ring:Show()
end
end
function F:SetCompassAnchor(anchor)
self.compassState=anchor.."_UP"
self.facingAnchor=anchor
local target=anchor=="STAR"and 180 or 0
self.fromAngle=self.visualAngle or 0
local delta=(target-self.fromAngle)%360
self.toAngle=self.fromAngle+delta;self.animationElapsed=0;self.animating=delta~=0
if not self.animating then self:RenderRotation(target)end
self:PaintHighlights()
end
function F:SetAnchor(anchor)
self:SetBossDisplayAnchor(anchor)
if anchor=="CENTER"then
self.compassState="IDLE";self:PaintHighlights()
local role=self:PlayerInfo()
if role=="TANK"then self:Say("BOSS带到中场","sfd_tank",5)end
return
end
self.bossAnchor=anchor
-- Boss movement and Point4 retain their original timing; STAR visuals wait for both cysts.
if anchor=="MOON"then self:SetCompassAnchor(anchor)end
self:RefreshPoint4()
self:PaintHighlights();self:RefreshAssignment(false)
local role=self:PlayerInfo()
if role=="TANK"then self:Say("BOSS带到"..(anchor=="MOON"and"月亮"or anchor=="STAR"and"星星"or"中场"),"sfd_tank",5)end
end
function F:BeginCycle(cycle)
self.cycle=cycle;self.cystRound=nil;self.secondAnchor=nil;self.points={};self.tokens={};self.tokenReady={};self.prewarn=nil;self.highlights={};self.ready=false;self.senderClicks=0;self.assignment=nil
T.Notify:CancelByTag("sfd_assignment");T.Notify:CancelByTag("sfd_pre")
T.moduleMap.WindOctagon:SFDResetCycle()
self:UpdateSenderStatus()
self:RefreshPoint4();self:PaintHighlights()
end
function F:RefreshPrewarn(voice)
-- Output retired; Prewarn retains round, anchor and highlight preparation.
end
function F:Prewarn(pair)
self.cystRound=pair==1 and"FIRST"or"SECOND"
if pair==2 then self.secondAnchor=self.bossAnchor end
local role,spec=self:PlayerInfo()
if not self:Eligible(role,spec)then return end
local first=pair==1 and 1 or 3
self.highlights=pair==2 and{[4]="LOW"}or{}
self:RefreshPoint4();self:PaintHighlights()
self.prewarn={pair=pair,expires=self:Expiry(first+1)}
self:RefreshPrewarn(true)
end
function F:Expire(slot)
self.highlights[slot]=nil
if self.assignment and self.assignment.slot==slot then
self.assignment=nil;T.Notify:CancelByTag("sfd_assignment")
T:Fire("ORB_POSITION_ALERT_COMPASS_HIDE")
end
if slot==2 or slot==4 then self.prewarn=nil;T.Notify:CancelByTag("sfd_pre")end
self:PaintHighlights()
end
F.expiries={{42,44,89,91},{169,171,216,218},{296,298,341,343}}
F.events={
{1,"anchor","MOON"},{8,"wind"},{26,"pre",1},{33,"anchor","STAR"},{70,"pre",2},{82,"anchor","CENTER"},
{127,"cycle",2},{127,"anchor","MOON"},{135,"wind"},{153,"pre",1},{160,"anchor","STAR"},{198,"pre",2},{206,"anchor","CENTER"},
{255,"cycle",3},{255,"anchor","MOON"},{262,"wind"},{280,"pre",1},{287,"anchor","STAR"},{322,"pre",2},{333,"anchor","CENTER"},
}
for _,row in ipairs(F.expiries)do F.events[#F.events+1]={row[2]+0.5,"rotate","STAR"}end
for cycle,row in ipairs(F.expiries)do for slot,time in ipairs(row)do F.events[#F.events+1]={time,"expire",slot,cycle}end end
for index,event in ipairs(F.events)do event.order=index end
table.sort(F.events,function(a,b)if a[1]==b[1]then return a.order<b.order end return a[1]<b[1]end)
function F:Tick(elapsed)
if not self.active then return end
elapsed=math.min(elapsed,T.SFD_LOGICAL_TIMELINE_END)
self.elapsed=elapsed
while self.events[self.nextEvent]and self.events[self.nextEvent][1]<=elapsed do
local event=self.events[self.nextEvent];self.nextEvent=self.nextEvent+1
if event[2]=="anchor"then self:SetAnchor(event[3])
elseif event[2]=="rotate"then self:SetCompassAnchor(event[3])
elseif event[2]=="cycle"then self:BeginCycle(event[3])
elseif event[2]=="pre"then self:Prewarn(event[3])
elseif event[2]=="expire"and event[4]==self.cycle then self:Expire(event[3])
elseif event[2]=="wind"and T.moduleMap.WindOctagon.db.senderShow then self:Say("看风","sfd_wind",5)end
end
T:Fire("SFD_TIMELINE_TICK",elapsed)
if elapsed>=T.SFD_LOGICAL_TIMELINE_END and self.ticker then self.ticker:Cancel();self.ticker=nil end
end
function F:Start(id,difficulty)
if id~=3420 or not self:IsMythic(difficulty)then return end
self:Stop()
self.active=true;self.startedAt=GetTime();self.nextEvent=1;self.elapsed=0;self.visualAngle=0;self.bossAnchor=nil;self.facingAnchor="MOON"
self.chatReceived=0
T:Fire("BOSS_ENGAGED",id,difficulty,self.startedAt)
self:BeginCycle(1)
self.ticker=C_Timer.NewTicker(0.05,function()self:Tick(GetTime()-self.startedAt)end)
end
function F:Stop()
if self.ticker then self.ticker:Cancel();self.ticker=nil end
for _,timer in ipairs(self.timers)do timer:Cancel()end
self.timers={};self.active=false;self.points={};self.tokens={};self.tokenReady={};self.prewarn=nil;self.highlights={};self.assignment=nil;self.ready=false;self.senderClicks=0
self.bossDisplayAnchor=nil;self.bossMoving=false;self.bossFieldY=nil;self.bossMoveTo=nil;self.bossMoveFrom=nil;self.bossMoveStarted=nil
self.cycle=nil;self.cystRound=nil;self.secondAnchor=nil;self.bossAnchor=nil;self.facingAnchor=nil;self.compassState="IDLE";self.animating=false;self.visualAngle=0;self.nextEvent=1
T.Notify:CancelAll();T:Fire("BOSS_DISENGAGED",3420)
if T.moduleMap.WindOctagon.db then T.moduleMap.WindOctagon:SFDStop()end
self:PaintHighlights();self:RenderBossIcon()
end
function F:AllowDirectSend()
if not self.active or not T.moduleMap.WindOctagon.db.senderShow or self.ready or(self.senderClicks or 0)>=3 then return false end
self.senderClicks=(self.senderClicks or 0)+1
self:UpdateSenderStatus()
return true
end
function F:UpdateSenderStatus()
local wind=T.moduleMap.WindOctagon
if wind and wind.SFDUpdateSenderStatus then wind:SFDUpdateSenderStatus()end
end
T:On("WIND_OCTAGON_MARKER_RECEIVED",function(slot,token)
F.chatReceived=(F.chatReceived or 0)+1
F.tokens[slot]=token
F.tokenReady[slot]=true
F.points[slot]=token
F:PaintHighlights()
F:RefreshPrewarn(false)
end)
