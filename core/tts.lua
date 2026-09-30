local T,_,L=unpack(SszorakFixedDirection)
local spec={
id="TTS",
displayName=L.notify_channel_tts,
needsAnchor=false,
OnInit=function(self)
local db=T.moduleMap["Notify"].db
db.channelDefaults.TTS=db.channelDefaults.TTS or{}
local d=db.channelDefaults.TTS
if d.voice==nil then d.voice=0 end
if d.volume==nil then d.volume=100 end
if d.rate==nil then d.rate=0 end
if not db._ttsVol100Migrated then
db._ttsVol100Migrated=true
if d.volume==80 then d.volume=100 end
end
end,
Fire=function(self,_notification,config)
local db=T.moduleMap["Notify"].db
local d=db.channelDefaults.TTS
local text=config.text or""
if text==""then return nil end
if not(C_VoiceChat and C_VoiceChat.SpeakText)then return nil end
local voice=config.voice or d.voice
local volume=config.volume or d.volume
local rate=config.rate or d.rate
pcall(C_VoiceChat.SpeakText,voice,text,rate,volume,true)
return nil
end,
}
T.LegacyTTS=spec
