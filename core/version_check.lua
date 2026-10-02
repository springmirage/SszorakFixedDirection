-- Version discovery only: deliberately independent of the tactical runtime clock.
local T=unpack(SszorakFixedDirection)
local V={prefix="SFDVER",rows={},serial=0,window=5,replyHistory={},pendingReplies={},nonce=math.random(1,16777215)}
T.VersionCheck=V
local HOME=LE_PARTY_CATEGORY_HOME or 1
local INSTANCE=LE_PARTY_CATEGORY_INSTANCE or 2
local MAX_MESSAGE=240
local frame=CreateFrame("Frame")
local function safe(value)
if not issecretvalue then return true end
local ok,secret=pcall(issecretvalue,value)
return ok and not secret
end
local function clean(value,maxLength)
return safe(value)and type(value)=="string"and #value>0 and #value<=maxLength
and not value:find("%c")
end
local function realmKey(realm)
return clean(realm,80)and realm:gsub("%s","")or nil
end
local function normalize(name)
if not clean(name,120)then return nil end
local character,realm=name:match("^([^%-]+)%-(.+)$")
if not character then character=name;realm=GetNormalizedRealmName()end
realm=realmKey(realm)
return realm and character.."-"..realm or nil
end
local function identity(unit)
local name,realm=UnitFullName(unit)
if not clean(name,80)or not safe(realm)then return nil end
local full=normalize(name:find("-",1,true)and name or name.."-"..((realm and realm~="")and realm or GetNormalizedRealmName()))
local guid=UnitGUID(unit)
return full,clean(guid,80)and guid or nil
end
local function context()
if IsInGroup(INSTANCE)or IsInRaid(INSTANCE)then
return{category=INSTANCE,raid=IsInRaid(INSTANCE),channel="INSTANCE_CHAT"}
end
if IsInRaid(HOME)then return{category=HOME,raid=true,channel="RAID"}end
if IsInGroup(HOME)then return{category=HOME,raid=false,channel="PARTY"}end
return{category=HOME,raid=false}
end
local function roster(ctx)
local rows,map={},{}
local function add(unit)
local name,guid=identity(unit)
if not name or map[name]then return end
local _,class=UnitClass(unit)
local online=UnitIsConnected(unit)
local row={name=name,guid=guid,class=safe(class)and class or nil,
online=safe(online)and online==true or false}
rows[#rows+1]=row;map[name]=row
end
if ctx.raid then
for i=1,GetNumGroupMembers(ctx.category)do add("raid"..i)end
else
add("player")
if ctx.channel then for i=1,GetNumSubgroupMembers(ctx.category)do add("party"..i)end end
end
table.sort(rows,function(a,b)return a.name<b.name end)
return rows,map
end
-- Only complete numeric versions are comparable. Other text remains visible verbatim.
function V.CompareVersions(a,b)
local function parse(value)
if not clean(value,64)then return nil end
value=value:gsub("^[vV]","")
if not value:match("^%d+[%.%d]*$")or value:find("%.%.")or value:sub(-1)=="."then return nil end
local result={}
for number in value:gmatch("%d+")do
if #number>9 then return nil end
result[#result+1]=tonumber(number)
end
return result
end
local left,right=parse(a),parse(b)
if not left or not right then return nil end
for i=1,math.max(#left,#right)do
local x,y=left[i]or 0,right[i]or 0
if x~=y then return x>y and 1 or -1 end
end
return 0
end
local function encode(value)return value:gsub("%%","%%25"):gsub("|","%%7C")end
local function decode(value,maxLength)
-- Strict escaping; malformed escapes and control characters never reach the UI.
if value:gsub("%%25",""):gsub("%%7C",""):find("%%")then return nil end
value=value:gsub("%%7C","|"):gsub("%%25","%%")
return clean(value,maxLength)and value or nil
end
local function validID(id)return clean(id,80)and id:match("^[%w%._:%-]+$")~=nil end
local function allowedChannel(channel)return channel=="RAID"or channel=="PARTY"or channel=="INSTANCE_CHAT"end
local function send(message,channel)
if not clean(message,MAX_MESSAGE)or not allowedChannel(channel)
or not(C_ChatInfo and C_ChatInfo.SendAddonMessage)then return false end
local ok,result=pcall(C_ChatInfo.SendAddonMessage,V.prefix,message,channel)
if not ok then return false end
local enum=Enum and Enum.SendAddonMessageResult
return result==true or(enum and result==enum.Success)or result==0
end
function V:Notify()
if self.onChanged then self.onChanged()end
end
function V:Refresh()
for _,row in ipairs(self.rows)do
row.connection=row.departed and"已离队"or(row.online and"在线"or"离线")
if row.version then
local comparison=self.CompareVersions(row.version,T.version)
row.judgment=comparison==nil and"版本格式未知"or(comparison==0 and"与本机一致"or(comparison<0 and"需要更新"or"高于本机版本"))
row.state="已加载"
elseif row.departed then row.state="已离队";row.judgment="未检测到版本"
elseif not row.online then row.state="离线";row.judgment="未检测到版本"
else row.state=self.scanning and"等待回报"or"未响应";row.judgment="无法确认版本"end
end
self:Notify()
end
function V:ReconcileRoster()
if not self.scanning then return end
local ctx=context()
local _,current=roster(ctx)
local sameContext=ctx.category==self.context.category and ctx.channel==self.context.channel
local newcomers=0
for _,row in ipairs(self.rows)do
local member=sameContext and current[row.name]
if not member or(member.guid and row.guid and member.guid~=row.guid)then row.departed=true
elseif not row.departed then row.online=member.online end
end
for name,member in pairs(current)do
local original=self.byName[name]
if not original or original.departed or(original.guid and member.guid and original.guid~=member.guid)then newcomers=newcomers+1 end
end
self.newcomers=newcomers
self:Refresh()
end
function V:Finish(reason)
if self.timer then self.timer:Cancel();self.timer=nil end
if self.countdown then self.countdown:Cancel();self.countdown=nil end
self.scanning=false;self.remaining=0;self.finishedAt=GetTime()
if reason then self.message=reason end
self:Refresh()
end
function V:EnsureReady()
if self.ready then return true end
if not(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix)then return false end
local ok,result=pcall(C_ChatInfo.RegisterAddonMessagePrefix,self.prefix)
local enum=Enum and Enum.RegisterAddonMessagePrefixResult
self.ready=ok and(result==true or result==0 or result==1
or(enum and(result==enum.Success or result==enum.DuplicatePrefix)))
return self.ready==true
end
function V:StartScan()
if self.scanning then return false end
if InCombatLockdown()then self.message="请脱战后检测版本。";self:Notify();return false end
local now=GetTime()
if self.lastScan and now-self.lastScan<5 then return false end
self.lastScan=now;self.startedAt=now;self.startedEpoch=GetServerTime()
self.serial=self.serial+1;self.context=context()
self.rows,self.byName=roster(self.context)
self.localName,self.localGUID=identity("player")
if not self.localName or not self.localGUID then self:Finish("无法读取本机身份，未完成检测。");return false end
self.scanID=string.format("%s:%d:%d:%x:%d",self.localGUID or"local",self.startedEpoch,math.floor(now*1000),self.nonce,self.serial)
self.remaining=5;self.newcomers=0;self.message=nil
local me=self.localName and self.byName[self.localName]
if me then me.version=T.version;me.receivedAt=now;me.source="本机直接读取";me.online=true end
if not self.context.channel then self:Finish("未组队，仅显示本机。");return true end
if not self:EnsureReady()then self:Finish("通信前缀注册失败，未完成远程检测。");return false end
self.scanning=true
-- Start state and deadline precede SendAddonMessage, including synchronous loopback in tests.
self.deadline=now+self.window
if not send("Q|1|"..self.scanID,self.context.channel)then
self:Finish("查询发送失败，远程状态无法确认。");return false
end
self.timer=C_Timer.NewTimer(self.window,function()V:ReconcileRoster();V:Finish()end)
self.countdown=C_Timer.NewTicker(.2,function()
local current=GetTime()
V.remaining=math.ceil(V.deadline-current)
V:Notify()
end)
self:Refresh();return true
end
local function onMessage(prefix,message,channel,sender)
if prefix~=V.prefix or not allowedChannel(channel)or not clean(message,MAX_MESSAGE)then return end
local senderName=normalize(sender)
local ctx=context()
if channel~=ctx.channel then return end
local _,members=roster(ctx)
local member=senderName and members[senderName]
if not member then return end
local queryID=message:match("^Q|1|([^|]+)$")
if queryID and validID(queryID)then
local me=identity("player")
if senderName==me or not V:EnsureReady()then return end
local now=GetTime()
for name,history in pairs(V.replyHistory)do
if now-history.at>30 or not members[name]then V.replyHistory[name]=nil end
end
local previous=V.replyHistory[senderName]
-- Per requester, not global: simultaneous scans by different members both get a reply.
if previous and(previous.id==queryID or now-previous.at<5)then return end
V.replyHistory[senderName]={id=queryID,at=now}
local key=senderName.."|"..queryID
V.pendingReplies[key]=C_Timer.NewTimer(.05+math.random()*.2,function()
V.pendingReplies[key]=nil
local active=context()
if active.category~=ctx.category or active.channel~=channel then return end
local _,current=roster(active)
if not current[senderName]or current[senderName].guid~=member.guid then return end
send("R|1|"..queryID.."|"..encode(senderName).."|"..encode(T.version),channel)
end)
return
end
local id,target,version=message:match("^R|1|([^|]+)|([^|]+)|([^|]+)$")
if not id or not validID(id)or not V.scanning or GetTime()>=V.deadline or id~=V.scanID then return end
target=decode(target,120);version=decode(version,64)
if not target or normalize(target)~=V.localName or not version then return end
local row=V.byName[senderName]
if not row or row.departed or not row.guid or row.guid~=member.guid or row.version then return end
V:ReconcileRoster()
if row.departed or not row.online then return end
row.version=version;row.receivedAt=GetTime();row.source="本轮关联回报";row.state="已加载"
V:Refresh()
end
frame:SetScript("OnEvent",function(_,event,...)
if event=="CHAT_MSG_ADDON"then onMessage(...)
elseif event=="PLAYER_LOGIN"then V:EnsureReady()
elseif event=="GROUP_ROSTER_UPDATE"then V:ReconcileRoster()
elseif event=="PLAYER_ENTERING_WORLD"then
if V.scanning then V:Finish("场景切换，检测已结束，请重新检测。")end
for key,timer in pairs(V.pendingReplies)do timer:Cancel();V.pendingReplies[key]=nil end
elseif event=="PLAYER_LOGOUT"then
if V.scanning then V:Finish()end
for key,timer in pairs(V.pendingReplies)do timer:Cancel();V.pendingReplies[key]=nil end
end
end)
frame:RegisterEvent("PLAYER_LOGIN");frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE");frame:RegisterEvent("PLAYER_ENTERING_WORLD");frame:RegisterEvent("PLAYER_LOGOUT")
