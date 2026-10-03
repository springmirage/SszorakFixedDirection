local T=unpack(SszorakFixedDirection)
local P={PREFIX="SFD_SOAK",editable={1,2,6}}
T.SoakConfig=P
local function secret(v)return issecretvalue and issecretvalue(v)or false end
local function finite(v)return not secret(v)and type(v)=="number"and v==v and v>-math.huge and v<math.huge end
local function round(v)return math.floor(v+.5)end
function P:Report(reason)
print("SFD 分担设置拒绝："..reason)
if T.SessionLog then T.SessionLog:SafeRecord("CONFIG_REJECTED",{reason=reason})end
end
function P:Reject(reason)self:Report(reason);return false,reason end
function P:Defaults()return {[1]={mode="E",value=70},[2]={mode="E",value=94},[6]={mode="E",value=96}}end
function P:Copy(c)local out={};for _,i in ipairs(self.editable)do out[i]={mode=c[i].mode,value=c[i].value}end;return out end
function P:ParseNumber(s)
if secret(s)or type(s)~="string"then return nil end
s=s:match("^%s*(.-)%s*$")
if not(s:match("^%d+$")or s:match("^%d+%.%d+$"))then return nil end
local n=tonumber(s);return finite(n)and n or nil
end
function P:ParseTime(s)
if secret(s)or type(s)~="string"then return nil end
s=s:match("^%s*(.-)%s*$"):gsub("：",":")
local minutes,seconds=s:match("^(%d+):([%d%.]+)$")
if minutes then
local m,v=self:ParseNumber(minutes),self:ParseNumber(seconds)
if not m or not v or v>=60 then return nil end
local total=m*60+v;return finite(total)and total or nil
end
return self:ParseNumber(s)
end
function P:FormatTime(v)
local s=string.format("%.6f",v):gsub("0+$",""):gsub("%.$","")
return s.." 秒"
end
function P:Build(c)
if type(c)~="table"then return nil,"配置格式无效。"end
local times={0,0,151,202,278,0};local energy={};local out={}
for i=1,6 do
local base=i==1 and -10 or times[i-1]+((i==3 or i==5)and 28 or 3)
if i==3 or i==4 or i==5 then
local raw=(times[i]-base)*2
if raw>=100 or round(raw)>=100 then return nil,"第"..i.."次时间固定，预计整数怒气必须小于100。第2次必须晚于73.25秒，请调整第1、2次设置。"end
energy[i]=round(raw)
else
local row=c[i]
if type(row)~="table"or(row.mode~="E"and row.mode~="T")or not finite(row.value)then return nil,"第"..i.."次输入无效。"end
local raw
if row.mode=="E"then
raw=row.value
if raw~=math.floor(raw)then return nil,"第"..i.."次怒气必须是整数。"end
times[i]=base+raw/2
else
times[i]=row.value;raw=(times[i]-base)*2
end
-- Validate before rounding too: a time equivalent to <60 or >=100 is invalid.
if raw<60 or raw>=100 or round(raw)>99 then return nil,"第"..i.."次对应怒气必须为60–99的整数。"end
energy[i]=round(raw);out[i]={mode=row.mode,value=row.value}
end
end
return out,times,energy
end
function P:IsBusy()
return InCombatLockdown()or(T.Fixed and T.Fixed.active)or(T.TestHarness and T.TestHarness.active)
end
function P:Apply(c,source)
if self:IsBusy()then return self:Reject("请先结束战斗或停止测试，再修改分担设置。")end
local valid,times,energy=self:Build(c)
if not valid then return self:Reject(times)end
self.config=valid;self.mod.db.soakSettings=self:Copy(valid)
self.mod.WAVES=times;self.mod.TARGET_ENERGY=energy
T:Fire("SOAK_SETTINGS_UPDATED",source or"本地保存")
return true
end
local function apiSuccess(result,enumName)
local e=Enum and Enum[enumName]
return result==true or(e and e.Success~=nil and result==e.Success)or false
end
function P:LeaderName()
if not IsInRaid or not IsInRaid()or not UnitIsGroupLeader or not UnitFullName then return nil end
for i=1,GetNumGroupMembers()do
local unit="raid"..i;local leader=UnitIsGroupLeader(unit)
if not secret(leader)and leader then
local name,realm=UnitFullName(unit)
if secret(name)or secret(realm)or type(name)~="string"then return nil end
realm=(realm and realm~=""and realm)or(GetNormalizedRealmName and GetNormalizedRealmName())
if secret(realm)or type(realm)~="string"then return nil end
return name.."-"..realm:gsub("%s","")
end
end
end
function P:SenderName(sender)
if secret(sender)or type(sender)~="string"then return nil end
local name,realm=sender:match("^([^%-]+)%-(.+)$")
if not name then name=sender;realm=GetNormalizedRealmName and GetNormalizedRealmName()end
if secret(realm)or type(realm)~="string"then return nil end
return name.."-"..realm:gsub("%s","")
end
function P:Encode(c,revision)
local parts={"1",string.format("%.0f",revision)}
for _,i in ipairs(self.editable)do parts[#parts+1]=c[i].mode;parts[#parts+1]=string.format("%.17g",c[i].value)end
return table.concat(parts,"|")
end
function P:Decode(msg)
if secret(msg)then return nil,"消息内容为受保护值，无法读取。"end
if type(msg)~="string"or #msg>255 then return nil,"消息类型或长度无效。"end
if msg:match("^([^|]+)")~="1"then return nil,"不支持此分担配置协议版本。"end
local revision,m1,v1,m2,v2,m6,v6=msg:match("^1|(%d+)|([ET])|([%d%.]+)|([ET])|([%d%.]+)|([ET])|([%d%.]+)$")
if not revision then return nil,"消息字段、设置模式或数值格式无效。"end
revision=tonumber(revision)
if not finite(revision)or revision<1 or revision>9007199254740991 then return nil,"消息序号无效。"end
local c={[1]={mode=m1,value=self:ParseNumber(v1)},[2]={mode=m2,value=self:ParseNumber(v2)},[6]={mode=m6,value=self:ParseNumber(v6)}}
local valid,reason=self:Build(c)
if not valid then return nil,reason end
return valid,revision
end
function P:Receive(prefix,msg,channel,sender)
-- Other addons' traffic is not a rejected SFD configuration.
if secret(prefix)or prefix~=self.PREFIX then return end
if self:IsBusy()then return self:Reject("战斗或测试期间不接收分担设置。")end
if not self.commReady then return self:Reject("通信前缀未注册，无法接收。")end
if secret(channel)then return self:Reject("消息频道为受保护值，无法确认。")end
if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()then return self:Reject("客户端处于插件消息限制状态，无法接收。")end
if channel~="RAID"and channel~="INSTANCE_CHAT"then return self:Reject("只接受团队频道的分担设置。")end
local leader=self:LeaderName();local author=self:SenderName(sender)
if not leader then return self:Reject("不在团队或无法确认当前团长身份。")end
if not author then return self:Reject("无法确认消息发送者的完整角色名。")end
if author~=leader then return self:Reject("消息发送者不是当前团长。")end
local c,revision=self:Decode(msg)
if not c then return self:Reject(revision)end
if self.lastSender==author and revision<=(self.lastReceived or 0)then
return self:Reject(revision==self.lastReceived and"重复配置消息，已处理此序号。"or"晚到的旧配置消息，序号低于已接收配置。")
end
if self:Apply(c,"收到团长配置："..author)then self.lastSender=author;self.lastReceived=revision end
end
function P:Send()
if self:IsBusy()then return self:Reject("请脱战并停止测试后发送。")end
if not self.commReady then return self:Reject("插件通信前缀注册失败，无法发送。")end
if not IsInRaid or not IsInRaid()or not UnitIsGroupLeader then return self:Reject("请加入团队后由团长发送。")end
local leader=UnitIsGroupLeader("player")
if secret(leader)or not leader then return self:Reject("只有团长可以发送分担设置。")end
if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()then return self:Reject("当前客户端处于插件消息限制状态。")end
if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()then return self:Reject("当前客户端限制插件消息发送。")end
if GetTime()-(self.lastSendTime or -math.huge)<2 then return self:Reject("发送过于频繁，请稍后再试。")end
local revision=math.max(math.floor((time and time()or GetTime())*1000),(self.lastSentRevision or 0)+1)
local channel=IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2)and"INSTANCE_CHAT"or"RAID"
local ok,result=pcall(C_ChatInfo.SendAddonMessage,self.PREFIX,self:Encode(self.config,revision),channel)
if not ok or not apiSuccess(result,"SendAddonMessageResult")then return self:Reject("发送失败或被限流，请稍后重试。")end
self.lastSendTime=GetTime();self.lastSentRevision=revision
self.lastSender=self:LeaderName();self.lastReceived=revision
return true,"已发送团队配置；接收者需安装V0.8或支持同一协议的版本。"
end
function P:Initialize(mod)
self.mod=mod
local valid,times,energy=self:Build(mod.db.soakSettings or self:Defaults())
if not valid then self:Report("已保存配置无效："..times.." 本次使用默认配置。");valid,times,energy=self:Build(self:Defaults())end
self.config=valid;mod.WAVES=times;mod.TARGET_ENERGY=energy
-- Invalid historical values remain in the saved table until the player saves.
self.frame=CreateFrame("Frame")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage then
local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,self.PREFIX)
self.commReady=ok and(apiSuccess(result,"RegisterAddonMessagePrefixResult")or(Enum and Enum.RegisterAddonMessagePrefixResult and result==Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix))
if self.commReady then self.frame:RegisterEvent("CHAT_MSG_ADDON")end
if not self.commReady then self:Report("插件通信前缀注册失败，发送功能不可用。")end
end
self.frame:SetScript("OnEvent",function(_,event,...)if event=="CHAT_MSG_ADDON"then self:Receive(...)end end)
end
