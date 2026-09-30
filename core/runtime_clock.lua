local T=unpack(SszorakFixedDirection)
-- Local adapters only; never replace Blizzard globals.
local liveTime,liveTimer,liveTicker=GetTime,C_Timer.NewTimer,C_Timer.NewTicker
T.SFD_LOGICAL_TIMELINE_END=390
T.RuntimeClock={}
function T.RuntimeClock.GetTime()
local h=T.TestHarness
if h and h.active then return h.elapsed end
return liveTime()
end
function T.RuntimeClock.NewTimer(delay,callback)
local h=T.TestHarness
if h and h.active then return h:Timer(delay,callback)end
return liveTimer(delay,callback)
end
function T.RuntimeClock.NewTicker(delay,callback)
local h=T.TestHarness
if h and h.active then return h:Timer(delay,callback,delay)end
return liveTicker(delay,callback)
end
