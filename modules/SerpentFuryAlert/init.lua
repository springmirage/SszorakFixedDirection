local T=unpack(SszorakFixedDirection)
local mod=T:NewModule("SerpentFuryAlert","毒蛇之怒")
mod.TAG="sfd_serpent_fury"
-- Reserved recording paths. This release continues using the existing TTS wrapper.
mod.VOICE_FILES={gather=T.addonPath.."media\\SerpentFury\\gather.ogg",switch=T.addonPath.."media\\SerpentFury\\switch.ogg",three=T.addonPath.."media\\SerpentFury\\three.ogg",two=T.addonPath.."media\\SerpentFury\\two.ogg",one=T.addonPath.."media\\SerpentFury\\one.ogg",go=T.addonPath.."media\\SerpentFury\\go.ogg"}
-- Configured estimates use public settings, never live restricted power.
mod.STAGES={
{offset=-6,text="大团进",voice="集合分担"},
{offset=-4,text="开关：4",voice="开关"},
{offset=-3,text="开关：3",voice="3"},
{offset=-2,text="开关：2",voice="2"},
{offset=-1,text="开关：1",voice="1"},
{offset=0,text="开关：进",voice="进"},
}
mod.ENERGY_STAGES={
{offset=-6,text="大团进",voice="集合分担"},
{offset=-4,text="开关看能量",voice="开关看能量"},
{offset=-2,text="2",voice="2"},
{offset=-1,text="1",voice="1"},
}
function mod:StagesForWave(wave)
return(wave==1 or wave==2 or wave==6)and self.ENERGY_STAGES or self.STAGES
end
function mod:Stop()
T.Notify:CancelByTag(self.TAG)
self.active=false;self.currentWave=nil;self.currentStage=nil;self.lastExecutedStage=nil
end
function mod:SetEnabled(enabled)
self.db.enabled=enabled==true
if not self.db.enabled then self:Stop()
elseif T.Fixed.active then self.active=true;self:Tick(T.RuntimeClock.GetTime()-T.Fixed.startedAt)end
end
function mod:OnDisable()self:Stop()end
function mod:Resolve(elapsed)
for wave,t in ipairs(self.WAVES)do
local stages=self:StagesForWave(wave)
local ending=stages==self.ENERGY_STAGES and t or t+1
if elapsed>=t-6 and elapsed<ending then
for stage=#stages,1,-1 do
if elapsed>=t+stages[stage].offset then
local finish=stage==#stages and ending or t+stages[stage+1].offset
return wave,stage,finish
end
end
end
end
end
function mod:Tick(elapsed)
if not self.active or not self.db.enabled then return end
-- Harness replay must not submit expired intermediate stages from a skipped frame.
if T.TestHarness and T.TestHarness.advancingTo then return end
local wave,stage,finish=self:Resolve(elapsed)
if not wave then
if self.currentStage then T.Notify:CancelByTag(self.TAG)end
self.currentWave=nil;self.currentStage=nil
return
end
local key=(wave-1)*#self.STAGES+stage
if self.lastExecutedStage==key then return end
self.currentWave=wave;self.currentStage=stage;self.lastExecutedStage=key
local cue=self:StagesForWave(wave)[stage]
T.Notify:Schedule({tag=self.TAG,channels={
SERPENT_FURY={text=cue.text,duration=finish-elapsed,attention=true},
TTS={text=cue.voice},
}})
end
function mod:NextEvent(elapsed)
for wave,t in ipairs(self.WAVES)do
for _,stage in ipairs(self:StagesForWave(wave))do
local at=t+stage.offset
if at>elapsed then return at,stage.text end
end
end
end
function mod:OnInit()
if self.db.enabled==nil then self.db.enabled=true end
T.SoakConfig:Initialize(self)
self:Stop()
T:On("BOSS_ENGAGED",function(id,difficulty)
self:Stop()
self.active=id==3420 and T.Fixed:IsMythic(difficulty)and self.db.enabled or false
end)
T:On("BOSS_DISENGAGED",function()self:Stop()end)
T:On("SFD_TIMELINE_TICK",function(elapsed)self:Tick(elapsed)end)
end
function mod:OnLogout()self:Stop()end
