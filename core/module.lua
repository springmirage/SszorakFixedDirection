local T,C,L=unpack(SszorakFixedDirection)
local tinsert=table.insert
local _subs={}
function T:On(event,fn)
assert(type(event)=="string","T:On 需要字符串 event")
assert(type(fn)=="function","T:On 需要函数 callback")
_subs[event]=_subs[event]or{}
local moduleName
if T.PerformanceProfiler then
moduleName=T.PerformanceProfiler:DetectCallerModule()
end
tinsert(_subs[event],{
callback=fn,
moduleName=moduleName,
})
end
function T:Off(event,fn)
local list=_subs[event]
if not list then return end
for i=#list,1,-1 do
if list[i].callback==fn then tremove(list,i)end
end
end
function T:Fire(event,...)
local list=_subs[event]
if not list then return end
local profiler=T.PerformanceProfiler
local profileDeep=profiler and profiler._deepActive
local perfRecord,perfStartedAt
if profileDeep then
perfRecord,perfStartedAt=profiler:BeginEvent(event)
end
for i=1,#list do
local subscriber=list[i]
local moduleRecord,moduleStartedAt,moduleName,moduleRoot
if profileDeep and subscriber.moduleName then
moduleRecord,moduleStartedAt,moduleName,moduleRoot=
profiler:BeginModule(
subscriber.moduleName,"Event."..event)
end
local ok,err=pcall(subscriber.callback,...)
if moduleRecord then
profiler:EndModule(
moduleRecord,moduleStartedAt,moduleName,moduleRoot)
end
if not ok then
print(string.format(
"|cffff4444SszorakFixedDirection|r event '%s' callback error: %s",
event,tostring(err)))
end
end
if perfRecord then
profiler:EndEvent(perfRecord,perfStartedAt)
end
end
function T:NewModule(name,displayName)
assert(type(name)=="string"and name~="",
"SszorakFixedDirection:NewModule 需要一个非空字符串作为模块名")
assert(not T.moduleMap[name],
"SszorakFixedDirection: 模块 '"..name.."' 已注册，不能重复注册")
local mod={
name=name,
displayName=displayName or name,
db=nil,
options=nil,
}
mod.OnInit=T.noop
mod.OnLogin=T.noop
mod.OnLogout=T.noop
mod._minimapMenuEntries={}
function mod:RegisterMinimapMenu(text,callback)
tinsert(self._minimapMenuEntries,{text=text,func=callback})
T:Fire("MINIMAP_MENU_UPDATED")
end
local panel=CreateFrame("Frame",nil,UIParent)
panel:Hide()
panel.isLoaded=false
panel.Load=T.noop
mod.options=panel
tinsert(T.modules,mod)
T.moduleMap[name]=mod
return mod
end
