local T=unpack(SszorakFixedDirection)
local panel=CreateFrame("Frame","SszorakFixedDirectionPositionSettings",UIParent,"BasicFrameTemplateWithInset")
panel:SetSize(360,170);panel:SetPoint("CENTER");panel:Hide()
panel.title=panel:CreateFontString(nil,"OVERLAY","GameFontHighlight")
panel.title:SetPoint("TOP",0,-7);panel.title:SetText("SFD "..T.version.." · 位置设置")
local hint=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
hint:SetPoint("TOP",0,-38);hint:SetText("点击后拖动对应显示，关闭面板完成。")
local function button(text,y,fn)
    local b=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    b:SetSize(270,30);b:SetPoint("TOP",0,y);b:SetText(text);b:SetScript("OnClick",fn)
end
button("罗盘：调整位置",-68,function()
    local wind=T.moduleMap.WindOctagon
    wind:SetCompassLocked(not wind:IsCompassLocked())
end)
button("Boss 能量值：调整位置",-108,function()
    local energy=T.moduleMap.BossEnergy
    energy:SetPositionEditing(not energy.editing)
end)
panel:SetScript("OnHide",function()
    T.moduleMap.WindOctagon:SetCompassLocked(true)
    T.moduleMap.BossEnergy:SetPositionEditing(false)
end)
UISpecialFrames[#UISpecialFrames+1]=panel:GetName()
SLASH_SSZORAKFIXEDDIRECTION1="/sfd";SLASH_SSZORAKFIXEDDIRECTION2="/m5"
SlashCmdList.SSZORAKFIXEDDIRECTION=function()panel:SetShown(not panel:IsShown())end
T.PositionSettings=panel
