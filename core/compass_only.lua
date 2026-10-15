local T = unpack(SszorakFixedDirection)
T.compassOnlyMode = true

local driver = CreateFrame("Frame")
local ticker
local startedAt
local nextEvent = 1
local function stop()
    if ticker then ticker:Cancel(); ticker = nil end
    local fixed = T.Fixed
    fixed.active = false
    fixed.highlights = {}
    fixed.visualAngle = 0
    fixed.animating = false
    fixed.bossAnchor = nil
    fixed.facingAnchor = nil
    fixed.compassState = "IDLE"
    fixed.fromAngle = nil
    fixed.toAngle = nil
    fixed.animationElapsed = 0
    fixed.bossDisplayAnchor = nil
    fixed.bossMoving = false
    fixed.bossMoveTo = nil
    fixed.bossMoveFrom = nil
    fixed.bossMoveStarted = nil
    fixed.bossFieldY = nil
    fixed:RenderRotation(0)
    local wind = T.moduleMap.WindOctagon
    if wind then wind:SetCompassEncounterOnly(false) end
end

local function start(id, difficulty)
    stop()
    if id ~= 3420 or not T.Fixed:IsMythic(difficulty) then return end
    local fixed = T.Fixed
    fixed.active = true
    fixed.highlights = {}
    fixed:SetAnchor("MOON")
    T.moduleMap.WindOctagon:SetCompassEncounterOnly(true)
    startedAt = GetTime()
    nextEvent = 1
    -- Reuse the original preset compass movement only; no assignment or reminder events.
    ticker = C_Timer.NewTicker(.05, function()
        local elapsed = GetTime() - startedAt
        while fixed.events[nextEvent] and fixed.events[nextEvent][1] <= elapsed do
            local event = fixed.events[nextEvent]
            nextEvent = nextEvent + 1
            if event[2] == "anchor" then
                fixed:SetAnchor(event[3])
            elseif event[2] == "rotate" then
                fixed:SetCompassAnchor(event[3])
            end
        end
        if elapsed >= T.SFD_LOGICAL_TIMELINE_END then ticker:Cancel(); ticker = nil end
    end)
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ENCOUNTER_START")
driver:RegisterEvent("ENCOUNTER_END")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent", function(_, event, ...)
    local wind = T.moduleMap.WindOctagon
    if event == "ADDON_LOADED" then
        if (...) ~= T.addonName then return end
        local saved = SszorakFixedDirectionDB
        local original = saved and saved.modules and saved.modules.WindOctagon
        wind.db = {}
        for key, value in pairs(original or {}) do wind.db[key] = value end
        -- Apply defaults and migrations to a runtime copy, preserving saved configuration.
        wind.db.enabled=true;wind.db.compassEnabled=true;wind.db.compassLocked=true
        wind.db.senderShow=false;wind.db.senderAnywhere=false
        wind:OnInit()
    elseif event == "PLAYER_LOGIN" then
        wind:OnLogin()
        -- Show the compass after a mid-fight reload; do not invent elapsed encounter time.
        local _, _, difficulty = GetInstanceInfo()
        wind:SetCompassEncounterOnly(UnitExists("boss1") and T.Fixed:IsMythic(difficulty))
    elseif event == "ENCOUNTER_START" then
        local id, _, difficulty = ...
        start(id, difficulty)
    elseif event == "ENCOUNTER_END" or event == "PLAYER_LOGOUT" then
        stop()
    elseif event == "PLAYER_ENTERING_WORLD" then
        stop()
        local _, _, difficulty = GetInstanceInfo()
        wind:SetCompassEncounterOnly(UnitExists("boss1") and T.Fixed:IsMythic(difficulty))
    end
end)
