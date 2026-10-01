-- Minimal standalone adapter for the legacy Notify TEXT/TTS contract.
local T=unpack(SszorakFixedDirection)
local C_Timer=T.RuntimeClock
local mod=T:NewModule("Notify","提示")
local active={}
local pool={}
T.Notify={}
-- Adapter for the copied legacy anchor editor; retain the SFD notification sink.
local textChannel={id="TEXT",displayName="文字提示（整组）",needsAnchor=true,settingsSchema={
{key="alignment",type="dropdown",label="对齐",options={{text="居左",value="LEFT"},{text="居中",value="CENTER"},{text="居右",value="RIGHT"}}},
{key="grow",type="dropdown",label="延伸方向",options={{text="向上",value="UP"},{text="向下",value="DOWN"}}},
{key="size",type="slider",label="字号",min=14,max=48,step=2},
}}
local serpentChannel={id="SERPENT_FURY",displayName="毒蛇之怒文字",needsAnchor=true,settingsSchema=textChannel.settingsSchema}
function serpentChannel:OnInit()
local db=mod.db
db.anchors=db.anchors or{}
db.anchors.SERPENT_FURY=db.anchors.SERPENT_FURY or{point="CENTER",relPoint="CENTER",x=0,y=270}
db.channelDefaults.SERPENT_FURY=db.channelDefaults.SERPENT_FURY or{size=30,alignment="CENTER",grow="UP"}
end
function textChannel:OnInit()
local db=mod.db
db.anchors=db.anchors or{}
db.anchors.TEXT=db.anchors.TEXT or{point="CENTER",relPoint="CENTER",x=0,y=145}
db.channelDefaults.TEXT=db.channelDefaults.TEXT or{size=30,alignment="CENTER",grow="UP"}
end
local function fitAttention(frame)
if not(frame.attention and frame.fs)then return end
local fs=frame.fs
fs:SetWordWrap(false)
fs:SetWidth(0)
local width=fs:GetStringWidth()
local offset=frame.icon and frame.icon:IsShown()and 56 or 0
local textWidth=math.max(410,width+20)
fs:SetWidth(textWidth)
frame:SetWidth(math.max(440,textWidth+30+offset))
end
local function position(frame,tag)
local channel=frame.channel or"TEXT"
local d=mod.db.channelDefaults[channel];local a=mod.db.anchors[channel]
frame:ClearAllPoints()
local offset=tag=="sfd_pre"and(d.grow=="DOWN"and 60 or -60)or 0
frame:SetPoint(a.point,UIParent,a.relPoint,a.x,a.y+offset)
if frame.fs then frame.fs:SetFont(STANDARD_TEXT_FONT,d.size or 30,frame.attention and"THICKOUTLINE"or"OUTLINE");frame.fs:SetJustifyH(frame.attention and channel=="TEXT"and"CENTER"or(d.alignment or"CENTER"))end
fitAttention(frame)
end
function textChannel:Reposition()for tag,entry in pairs(active)do position(entry.frame,tag)end end
textChannel.UpdateAllSettings=textChannel.Reposition
serpentChannel.Reposition=textChannel.Reposition
serpentChannel.UpdateAllSettings=textChannel.Reposition
function T.Notify:GetChannel(id)if id=="TEXT"then return textChannel elseif id=="SERPENT_FURY"then return serpentChannel elseif id=="TTS"then return T.LegacyTTS end end
function T.Notify:ListChannels()return{textChannel,serpentChannel,T.LegacyTTS}end
function mod:OnInit()
self.db.channelDefaults=self.db.channelDefaults or{}
self.db.anchorVisibility=self.db.anchorVisibility or{}
textChannel:OnInit()
serpentChannel:OnInit()
T.LegacyTTS:OnInit()
end
local function release(tag,reason)
local entry=active[tag]
if not entry then return end
if entry.timer then entry.timer:Cancel()end
entry.frame:Hide()
entry.frame:SetScript("OnUpdate",nil)
entry.frame:SetScale(1)
pool[#pool+1]=entry.frame
active[tag]=nil
if entry.onClear then pcall(entry.onClear)end
if tag=="sszorak_orb_position"then
T:DiagnosticCall("Cleared",reason)
end
end
function T.Notify:CancelByTag(tag)release(tag)end
function T.Notify:CancelAll()
local tags={};for tag in pairs(active)do tags[#tags+1]=tag end
for _,tag in ipairs(tags)do release(tag)end
end
T.Notify._engine={CancelChannel=function(_,id)
local tags={};for tag,entry in pairs(active)do if entry.frame.channel==id then tags[#tags+1]=tag end end
for _,tag in ipairs(tags)do release(tag)end
end}
function T.Notify:Schedule(config)
local tag=config.tag or config.id
if tag=="sszorak_orb_position"then T:DiagnosticCall("PrepareShow")end
release(tag,tag=="sszorak_orb_position"and"REPLACED"or nil)
local channel=config.channels and config.channels.SERPENT_FURY and"SERPENT_FURY"or"TEXT"
local text=config.channels and config.channels[channel]
if text and mod.db.anchorVisibility[channel]~=false then
local f=table.remove(pool)or CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
f.channel=channel
f.attention=text.attention==true
f:SetScale(1);f:SetAlpha(1);f:SetScript("OnUpdate",nil);f:SetBackdrop(nil)
f:ClearAllPoints()
f:SetSize(f.attention and 440 or 680,f.attention and 84 or 95)
f:SetFrameStrata("DIALOG")
local fs=f.fs or f:CreateFontString(nil,"OVERLAY");f.fs=fs
fs:SetFont(STANDARD_TEXT_FONT,30,"OUTLINE");fs:ClearAllPoints();fs:SetPoint("CENTER",f,"CENTER",f.attention and text.renderIcon and 28 or 0,0);fs:SetWidth(f.attention and 410 or 680)
fs:SetWordWrap(not f.attention)
if f.icon then f.icon:Hide()end
if f.attention and text.renderIcon then
local icon=f.icon or f:CreateFontString(nil,"OVERLAY");f.icon=icon
icon:SetFont(STANDARD_TEXT_FONT,14,"OUTLINE");icon:ClearAllPoints();icon:SetPoint("LEFT",f,"LEFT",12,0)
icon:SetText("");pcall(text.renderIcon,icon);icon:Show()
end
local color=text.textColor or{1,0.15,0.5}
fs:SetTextColor(unpack(color))
position(f,tag)
if f.attention then
f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
f:SetBackdropColor(.025,.015,.035,.78)
f:SetBackdropBorderColor(1,.15,.5,1)
local started=text.attentionStart or C_Timer.GetTime()
local function animate(self)
local elapsed=math.max(0,C_Timer.GetTime()-started)
self:SetBackdropBorderColor(1,.15,.5,.45+.15*(.5+.5*math.cos(elapsed*math.pi)))
end
f:SetScript("OnUpdate",animate);animate(f)
end
local duration=text.duration or 10
local started=C_Timer.GetTime()
local function countdown(rem)
if rem>3 then return string.format("%.0f",math.ceil(rem))end
return string.format("%.1f",rem)
end
local rendered=true
if text.renderText then
local ok=pcall(text.renderText,fs,text.legacyLifetime and countdown(duration)or"")
rendered=ok
if not ok then fs:SetText("放球点数据缺失")end
else fs:SetText(text.text or"")end
fitAttention(f)
local entry={frame=f,onClear=text.onClear};active[tag]=entry
local fade=text.legacyLifetime and 0.5 or 0
if text.legacyLifetime then
local animate=f:GetScript("OnUpdate")
local nextUpdate=started+0.1
f:SetScript("OnUpdate",function(frame,...)
if animate then animate(frame,...)end
local now=C_Timer.GetTime()
if now>=nextUpdate then
nextUpdate=now+0.1
if text.renderText then pcall(text.renderText,fs,countdown(duration-(now-started)))end
fitAttention(frame)
end
if now>=started+duration then frame:SetAlpha(math.max(0,1-(now-started-duration)/fade))end
end)
end
entry.timer=C_Timer.NewTimer(duration+fade,function()if active[tag]==entry then release(tag,"DISPLAY_LIFETIME")end end)
f:Show()
if tag=="sszorak_orb_position"then
if rendered then T:DiagnosticCall("Shown")
else T:Diagnostic("ASSIGNMENT_REJECTED",{assignmentShown=false,assignmentRejected=true,rejectReason="UI_RENDER_ERROR"})end
end
elseif tag=="sszorak_orb_position"then
T:Diagnostic("ASSIGNMENT_REJECTED",{assignmentRejected=true,assignmentShown=false,rejectReason="TEXT_CHANNEL_HIDDEN"})
end
local voice=config.channels and config.channels.TTS
if voice then T.LegacyTTS:Fire(config,voice)end
end
