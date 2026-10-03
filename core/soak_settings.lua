local T=unpack(SszorakFixedDirection)
local S,W,P=T.Settings,T.W,T.SoakConfig
local function label(parent,value,x,y,width,size)
local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
fs:SetFont(STANDARD_TEXT_FONT,size or 13,"");fs:SetTextColor(.89,.92,.95)
fs:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);fs:SetJustifyH("LEFT");fs:SetWidth(width);fs:SetText(value)
return fs
end
local function button(parent,value,x,y,width,fn)
local b=W:Button(parent,value);b:SetPoint("TOPLEFT",x,y);b:SetSize(width,30);b:OnClick_(fn);return b
end
function S:ReadSoakDraft()
local c={}
for _,i in ipairs(P.editable)do
local row=self.soakRows[i];local mode=row.mode:GetValue_()
local value=mode=="T"and P:ParseTime(row.input:GetText())or P:ParseNumber(row.input:GetText())
if not value then return nil,"第"..i.."次格式无效：时间可填秒数或分:秒，怒气填整数。"end
c[i]={mode=mode,value=value}
end
return P:Build(c)
end
function S:PreviewSoakDraft()
local c,times,energy=self:ReadSoakDraft()
if not c then self.soakStatus:SetText(times);P:Report(times);return nil end
self.soakDraft=c
for i=1,6 do
local suffix=(i==3 or i==4 or i==5)and"\n（不推荐更改）"or""
self.soakRows[i].result:SetText("时间 "..P:FormatTime(times[i]).." · 怒气 "..energy[i]..suffix)
end
self.soakStatus:SetText("预览有效；点击保存后生效，团长可发送给团队。")
return c
end
function S:RefreshSoakPage(source)
if not self.soakRows then return end
self.soakDraft=P:Copy(P.config)
for i=1,6 do
local row=self.soakRows[i]
if row.mode then
row.mode:SetValue_(P.config[i].mode)
row.input:SetText(string.format("%.17g",P.config[i].value))
end
end
self:PreviewSoakDraft()
if source then self.soakStatus:SetText(source)end
end
function S:SaveSoakDraft(send)
local c=self:PreviewSoakDraft();if not c then return false end
local ok,message=P:Apply(c)
if not ok then self.soakStatus:SetText(message);return false end
if send then ok,message=P:Send();self.soakStatus:SetText(message);return ok end
self.soakStatus:SetText("已保存。新设置用于下一次开怪；团队同步需由团长点击发送。")
return true
end
function S:CreateSoakPage(p)
label(p,"分担设置",24,-22,510,20)
label(p,"第1、2、6次可按时间或怒气设置；怒气限60–99整数。\n第3、4、5次时间/怒气不可改，反算怒气也必须小于100。",24,-57,526,13)
label(p,"轮次",24,-108,44);label(p,"设置依据",78,-108,108);label(p,"输入值",199,-108,105);label(p,"换算结果",324,-108,226)
self.soakRows={}
for i=1,6 do
local index=i;local y=-138-(i-1)*46;local row={};self.soakRows[i]=row
label(p,"第"..i.."次",24,y-6,48)
if i==3 or i==4 or i==5 then
label(p,"固定时间",78,y-6,108)
row.input=label(p,tostring(P.mod.WAVES[i]).." 秒",199,y-6,105)
else
local choice=W:Dropdown(p);row.mode=choice;choice:SetPoint("TOPLEFT",78,y);choice:SetSize(108,28)
choice:SetItems_({{value="E",text="目标怒气"},{value="T",text="分担时间"}});choice:SetValue_(P.config[i].mode)
local edit=CreateFrame("EditBox",nil,p,"InputBoxTemplate");row.input=edit
edit:SetSize(105,28);edit:SetPoint("TOPLEFT",199,y);edit:SetAutoFocus(false);edit:SetMaxLetters(24)
edit:SetScript("OnEscapePressed",function(e)e:ClearFocus()end)
edit:SetScript("OnEnterPressed",function(e)S:PreviewSoakDraft();e:ClearFocus()end)
edit:SetScript("OnEditFocusLost",function()S:PreviewSoakDraft()end)
choice:OnPick_(function(mode)
local c=S.soakDraft or P.config;local valid,times,energy=P:Build(c)
if valid then row.input:SetText(string.format("%.17g",mode=="T"and times[index]or energy[index]))end
S:PreviewSoakDraft()
end)
end
row.result=label(p,"",324,y-2,226,12)
end
label(p,"时间示例：24.756、3:21、3：21（也支持分:秒的小数）。\n时间换算怒气按最近整数显示；固定轮次保持原来的4321进。",24,-423,526,12)
button(p,"保存设置",24,-467,112,function()S:SaveSoakDraft(false)end)
button(p,"团长：保存并发送",148,-467,190,function()S:SaveSoakDraft(true)end)
button(p,"恢复默认",350,-467,176,function()
local ok,message=P:Apply(P:Defaults(),"已恢复默认；尚未发送给团队。")
if not ok then S.soakStatus:SetText(message)end
end)
self.soakStatus=label(p,"",24,-509,526,12)
self:RefreshSoakPage()
end
T:On("SOAK_SETTINGS_UPDATED",function(source)S:RefreshSoakPage(source)end)
