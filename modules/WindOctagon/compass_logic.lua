local Compass={}
Compass.DIRECTIONS={
"north","northeast","east","southeast",
"south","southwest","west","northwest",
}
Compass.DEFAULT_MARKERS={5,3,6,7,1,4,2,8}
Compass.DEFAULT_ANGLE_OFFSET=0
Compass.MARKER_DIRECTION_OFFSET=0
Compass.MARKER_LAYOUT_VERSION=2
Compass.DEFAULT_MARKER_SIZE=34
Compass.DEFAULT_REFRESH_INTERVAL=0.03
local LEGACY_DIRECTION_WORKAROUND={8,5,3,6,7,1,4,2}
local function validMarker(value)
value=tonumber(value)
if not value then return nil end
value=math.floor(value)
if value<1 or value>8 then return nil end
return value
end
function Compass.NormalizeMarkers(source)
source=type(source)=="table"and source or{}
local normalized,used={},{}
for direction=1,8 do
local marker=validMarker(source[direction])
if marker and not used[marker]then
normalized[direction]=marker
used[marker]=true
end
end
local available={}
for _,marker in ipairs(Compass.DEFAULT_MARKERS)do
if not used[marker]then available[#available+1]=marker end
end
local nextAvailable=1
for direction=1,8 do
if not normalized[direction]then
normalized[direction]=available[nextAvailable]
nextAvailable=nextAvailable+1
end
end
return normalized
end
local function sameMarkers(first,second)
for direction=1,8 do
if first[direction]~=second[direction]then return false end
end
return true
end
function Compass.MarkerAngle(direction)
direction=math.max(1,math.min(8,math.floor(
tonumber(direction)or 1)))
return((direction-1)*45)
+Compass.DEFAULT_ANGLE_OFFSET
+Compass.MARKER_DIRECTION_OFFSET
end
function Compass.MigrateMarkers(source,layoutVersion)
local normalized=Compass.NormalizeMarkers(source)
if(tonumber(layoutVersion)or 0)>=Compass.MARKER_LAYOUT_VERSION then
return normalized,Compass.MARKER_LAYOUT_VERSION
end
if sameMarkers(normalized,LEGACY_DIRECTION_WORKAROUND)then
normalized=Compass.NormalizeMarkers(nil)
end
return normalized,Compass.MARKER_LAYOUT_VERSION
end
function Compass.AssignMarker(source,direction,marker)
direction=math.floor(tonumber(direction)or 0)
marker=validMarker(marker)
local result=Compass.NormalizeMarkers(source)
if direction<1 or direction>8 or not marker then return result end
local previous=result[direction]
local otherDirection
for index=1,8 do
if result[index]==marker then
otherDirection=index
break
end
end
result[direction]=marker
if otherDirection and otherDirection~=direction then
result[otherDirection]=previous
end
return result
end
function Compass.IsSupportedDifficulty(value)
value=tonumber(value)
return value==15 or value==16 or value==233
end
function Compass.ShouldRun(receiverEnabled,compassEnabled,debugEnabled)
return receiverEnabled==true
or compassEnabled==true
or debugEnabled==true
end
function Compass.ShouldShow(compassEnabled,encounterActive,previewing)
return compassEnabled==true
and(encounterActive==true or previewing==true)
end
function Compass.NormalizeRefreshInterval(value)
return math.max(
0.01,
math.min(
0.20,
tonumber(value)or Compass.DEFAULT_REFRESH_INTERVAL))
end
function Compass.DefaultScreenOffset(width)
return(tonumber(width)or 0)*0.25,0
end
function Compass.Geometry(value,markerSize)
local size=math.max(120,math.min(400,tonumber(value)or 220))
local outlineRadius=size*0.43
local markerRadius=outlineRadius*math.cos(math.pi/8)
markerSize=math.max(
16,
math.min(
80,
tonumber(markerSize)or Compass.DEFAULT_MARKER_SIZE))
return{
size=size,
outlineRadius=outlineRadius,
markerRadius=markerRadius,
markerSize=markerSize,
targetX=0,
targetY=size*0.25,
}
end
if rawget(_G,"SszorakFixedDirection")then
local T=unpack(SszorakFixedDirection)
T.WindOctagonCompass=Compass
end
return Compass
