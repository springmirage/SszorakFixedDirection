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
local function position(frame,tag)
local channel=frame.channel or"TEXT"
local d=mod.db.channelDefaults[channel];local a=mod.db.anchors[channel]
frame:ClearAllPoints()
local offset=tag=="sfd_pre"and(d.grow=="DOWN"and 60 or -60)or 0
frame:SetPoint(a.point,UIParent,a.relPoint,a.x,a.y+offset)
if frame.fs then frame.fs:SetFont(STANDARD_TEXT_FONT,d.size or 30,frame.attention and"THICKOUTLINE"or"OUTLINE");frame.fs:SetJustifyH(frame.attention and channel=="TEXT"and"CENTER"or(d.alignment or"CENTER"))end
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
local function release(tag)
local entry=active[tag]
if not entry then return end
if entry.timer then entry.timer:Cancel()end
entry.frame:Hide()
entry.frame:SetScript("OnUpdate",nil)
entry.frame:SetScale(1)
pool[#pool+1]=entry.frame
active[tag]=nil
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
release(tag)
local channel=config.channels and config.channels.SERPENT_FURY and"SERPENT_FURY"or"TEXT"
local text=config.channels and config.channels[channel]
if text and mod.db.anchorVisibility[channel]~=false then
local f=table.remove(pool)or CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
f.channel=channel
f.attention=text.attention==true
f:SetScale(1);f:SetScript("OnUpdate",nil);f:SetBackdrop(nil)
f:ClearAllPoints()
f:SetSize(f.attention and 440 or 680,f.attention and 84 or 95)
f:SetFrameStrata("DIALOG")
local fs=f.fs or f:CreateFontString(nil,"OVERLAY");f.fs=fs
fs:SetFont(STANDARD_TEXT_FONT,30,"OUTLINE");fs:ClearAllPoints();fs:SetPoint("CENTER",f,"CENTER",f.attention and text.renderIcon and 28 or 0,0);fs:SetWidth(f.attention and 410 or 680)
if f.icon then f.icon:Hide()end
if f.attention and text.renderIcon then
local icon=f.icon or f:CreateFontString(nil,"OVERLAY");f.icon=icon
icon:SetFont(STANDARD_TEXT_FONT,14,"OUTLINE");icon:ClearAllPoints();icon:SetPoint("LEFT",f,"LEFT",12,0)
icon:SetText("");pcall(text.renderIcon,icon);icon:Show()
end
fs:SetTextColor(1,0.15,0.5)
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
if text.renderText then
local ok=pcall(text.renderText,fs,"")
if not ok then fs:SetText("放球点数据缺失")end
else fs:SetText(text.text or"")end
local entry={frame=f};active[tag]=entry
entry.timer=C_Timer.NewTimer(text.duration or 10,function()if active[tag]==entry then release(tag)end end)
f:Show()
end
local voice=config.channels and config.channels.TTS
if voice then T.LegacyTTS:Fire(config,voice)end
end
