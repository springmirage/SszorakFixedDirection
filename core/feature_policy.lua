local T=unpack(SszorakFixedDirection)
-- Release policy is code-owned. SavedVariables never select active features.
local allowed={WindOctagon=true,BossEnergy=true}
T.compassOnlyMode=true
T.energyOnlyMode=true
function T:IsFeatureEnabled(name)return allowed[name]==true end
function T:SavePosition(module,key,value)
    SszorakFixedDirectionDB=SszorakFixedDirectionDB or {}
    local db=SszorakFixedDirectionDB
    db.modules=db.modules or {};db.modules[module]=db.modules[module] or {}
    db.modules[module][key]=value
end
