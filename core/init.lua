local addon,ns=...
ns[1]={};ns[2]={};ns[3]={}
SszorakFixedDirection=ns
local T=ns[1]
T.addonName=addon
T.addonPath="Interface\\AddOns\\"..addon.."\\"
T.modules={};T.moduleMap={};T.noop=function()end
-- The TOC is the sole release-version source, shared by UI, diagnostics and comms.
T.version=(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addon,"Version"))or"未知"
