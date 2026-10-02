# 版本检测维护参考：STT 源码审计与 SFD 适配边界

记录日期：2026-10-02（Asia/Shanghai）。后续维护 SFD 版本检测功能时先阅读本文。STT 源目录将被删除；本文保存已核实的实现细节，不要求再次访问 STT。SFD 的运行与测试不得依赖 STT。

## 1. 证据范围与源码定位

本记录根据本机文件重新读取整理，不根据截图或先前对话推断。STT/STT.toc 第 5 行版本为 `261002.3`；这个版本标签不能保证文件没有局部修改，因此同时记录原始文件字节的 SHA256。下面路径均相对原 AddOns 目录 `D:\World of Warcraft\_retail_\Interface\AddOns`，行号对应本次快照。

| 原文件 | 用途 | SHA256 |
|---|---|---|
| `STT/core/comm/version_check.lua` | 常驻查询、自动回复、昵称同步 | `0d109db30079655a53b5278ebd8fe6a32bd62a3b22dea8fa00cd8a5a7618dedd` |
| `STT_Options/options/version_check_options.lua` | 检测控制器、名单、缓存、结果界面 | `aced5c061e725e5ab41cf0c8726dfac9ae5548cd912f7a44d539845f1367ede5` |
| `STT/core/version.lua` | STT 专用版本解析和比较 | `f98bd7fc070e4bf94ecdccf39ff3ebb21b82ca5c8b2130a494f294cb7be28d74` |
| `STT/core/init.lua` | TOC 元数据到 T.Version 的初始化 | `2ac8fc4498e95117c0b81f2e67058e994ff41f3bddc2a367a749a02910557df2` |
| `STT/STT.toc` | STT 发布版本与入口 | `4535b4616d0961ffd23709c907f41e2c6ee860241993d82d5c71162fec3f38ac` |

### 加载入口与关键函数

- `STT/STT.toc` 加载 `load.xml`；`STT/load.xml` 第 4、19、33 行分别加载 `core/init.lua`、`core/version.lua`、`core/comm/version_check.lua`。
- 通信文件第 338 行附近获取 `T.Lite:GetAddon("STT")`，调用 `RegisterRuntime(Transport)`、`EnableRuntime(Transport)`。不是打开设置页之后才安装自动回报能力。
- 通信文件 `OnEnable`（313）、`OnDisable`（326）：注册 `STTVER`，监听 `CHAT_MSG_ADDON` 和 `PLAYER_REGEN_ENABLED`；关闭时解除事件并取消昵称批量计时器。
- Options 入口：`STT_Options/options/option_stubs.lua` 第 13 行注册 `versionCheck` 导航；`generated_module_load.xml` 第 11 行加载检测页文件；检测页底部第 884 行附近 `T.RegisterOptionModule` 指向 `RenderVersionCheck`（548）。
- 检测页 `EnsureTransportReady`（433 附近）通过 `Transport:RegisterOnReply(OnReply)` 绑定结果监听；通信层 `RegisterOnReply`（298）把回调存入集合，重复同一函数不会重复调用。
- 点击按钮（861）→ `VersionCheck:StartScan`（458）→ `CollectRoster`（172）→ `SendQuery`（383 附近）→ 通信层 `Transport:SendQuery`（255）→ `BuildQuery`（143）→ `SendRaw`（83）。
- 接收事件→通信层 `OnAddonMessage`（230）→ `OnQuery`（202）→ `BuildReply`（151）→ `SendRaw(...,"WHISPER",sender)`；回复到达→通信层 `OnReply`（215）→每个 `replyCallbacks`→检测页 `OnReply`（402）→ `ApplyVersion`（323）→ `RefreshStatuses`（342）→ `SortResults`（224 附近）→ `RefreshUI`（280 附近）。

## 2. STT 的真实线协议

独立插件消息前缀是 `STTVER`。不是普通聊天消息，不是 AceComm/序列化包；此模块直接调用 `C_ChatInfo.SendAddonMessage`。

```text
查询：Q|<scanID>|<发起者昵称，可为空>
回复：R|<版本号>|<scanID>|<回报者昵称，可为空>
```

字段顺序必须保持上述顺序，尤其回复中版本在检测编号之前。来源：通信文件第 143～158 行。

```lua
-- BuildQuery
return table.concat({"Q", EncodePart(scanID), EncodePart(GetNickname() or "")}, "|")
-- BuildReply
return table.concat({"R", EncodePart(GetVersion()), EncodePart(scanID),
    EncodePart(GetNickname() or "")}, "|")
```

空昵称仍有尾部 `|`。示例：`Q|123456|`，`R|261002.3|123456|`。回复目标不在报文里：由发送接口的 WHISPER 目标指定。通信层回调产生 `{version, scanID, nickname}`；**没有产生 `target` 字段**。检测页虽然存在 `payload.target` 检查（406），不能把它误认为当前 STT 协议传了目标字段。

### 编码及容错

`EncodePart`（45）先 `%`→`%25`，再 `|`→`%7C`，换行替换为空格；`DecodePart`（53）先解 `%7C` 再解 `%25`。`SplitMessage`（60）在末尾补 `|` 后按分隔符拆分，因此尾部空字段能被保留。

`OnAddonMessage` 根据首字段 Q/R 分派，并以原报文是否含昵称分隔符判断 `nicknamePresent`，缺少昵称时仍可处理版本与编号。没有看到该模块对所有字段个数、报文长度、编号字符集或版本格式进行严格拒绝校验；不要将这些能力写成它已有。

### 检测编号与其他查询

检测页 `StartScan`（483～485 附近）使用：

```lua
local scanID = tostring(math.floor((GetTime and GetTime() or 0) * 1000))
currentScanID = scanID
```

只有本地运行时间的毫秒，不带发起者 GUID、随机会话标识或序号。不同玩家可能生成相同编号；当前回复私聊发起者降低串扰，但编号本身不具全局唯一性。

通信模块还复用 Q/R 做队员昵称查询，`RequestRosterNicknames`（266～291）生成 `list-<毫秒>-<requestSerial>`，请求限流 5 秒。战斗中先保存 `pendingRosterRequest`，`OnPlayerRegenEnabled`（306）再执行。昵称变化 0.2 秒批量发出内部 `STT_ROSTER_NICKNAMES_CHANGED`；它不是额外的网络消息。

### 实际发送通道和发送者检查

- `GetGroupChannel`（68）：`IsInRaid()` 时 RAID，否则 `IsInGroup()` 时 PARTY，否则 nil。这里没有显式 `INSTANCE_CHAT` 分支。
- 查询走默认团队广播；回复（202～212）固定 WHISPER，target 使用事件 sender 原文。该事实比文件头“团队广播”的笼统注释更具体。
- `IsRosterSender`（102）检查 `UnitInRaid(sender)` 或 `UnitInParty(sender)`；它检查当前队伍成员，不是严格保存的本轮快照。
- `SendRaw` 直接调用 `C_ChatInfo.SendAddonMessage(PREFIX,message,channel,target)`；`IsSendSuccess`（76）接受 true、nil 或 `Enum.SendAddonMessageResult.Success`。前缀注册返回结果只记调试日志，没有阻止后续发送的严格失败状态。
- 因为接口限制、跨服私聊或实例通信的真实成功率不能只靠静态源码证明，本文不宣称该实现已经通过当前客户端实例团队实测。

## 3. 跨服角色名与名单

通信层 `NormalizeFullName`（109）：已有 `-` 则保留原文；缺服务器则使用 `GetNormalizedRealmName()`；`FullNameForUnit`（122）调用 `UnitFullName`。它用完整名字维护昵称缓存 `nicknameByFullName`。

检测页采用自己的名字实现（89～124）：`BuildFullName` 已含 `-` 时保留，否则补 `GetRealmName()`；`FullNameFromUnit` 使用 `UnitFullName`；`NormalizeSender` 用同一构造；展示短名调用 `Ambiguate(fullName,"short")`。两层默认服务器获取方法并不相同，不能概括为完全一致的归一化规则。

`CollectRoster`（172～214）：

- 团队：遍历 `raid1..GetNumGroupMembers()`，`GetRaidRosterInfo` 获取 classFile、online，优先 `UnitFullName`，失败才用 roster name。保留 fullName、短名、GUID、unitId。
- 小队：直接加自己，online=true；遍历 `party1..GetNumGroupMembers()-1`，用 `UnitIsConnected` 判断在线，`UnitClass` 获取职业。
- 检测页 `IsInAnyGroup/IsInAnyRaid`（70～85）会尝试 HOME、INSTANCE 和无参数接口；但名单计数及通信 `GetGroupChannel` 未统一传递类别，实例兼容不能仅凭前置检查推定成功。
- `RebuildLookup`（286）建立完整名和短名索引。两个同短名成员时，短名索引值设 false；`FindEntryBySender`（303）优先完整名，只有短名唯一时才退回短名。因此不能把所有跨服同名都靠短名匹配。
- 展示职业色来自 `RAID_CLASS_COLORS`（125）；昵称存在且不是缓存时显示职业色昵称与灰色角色名；缓存不显示本次昵称（141～151）。完整名主要用于数据匹配和悬浮提示，不保证主列表总是显示服务器。

## 4. 版本来源及判断规则

TOC 版本 `261002.3` 是当前审计快照。`STT/core/init.lua` 第 17～26 行通过 `C_AddOns.GetAddOnMetadata(addon,"Version")`，旧接口兜底 `GetAddOnMetadata`，得到 `T.Version`，缺失为 dev。

通信 `GetVersion`（138）再次优先读取 `C_AddOns.GetAddOnMetadata("STT","Version")`，退回 T.Version，最后 dev。检测页自己版本直接填 T.Version，不等待自己的网络回包。

`STT/core/version.lua` 第 6～17 行只支持 `数字.数字` 或单个数字（后者第二段补 0），其他输入解析为 `(0,0)`；不识别 V/v 前缀和多段语义版本。第 24～34 行先比第一段，再比第二段，按数字比较，不是字符串排序。`261002.10` 大于 `261002.9`，但 SFD 的 `V0.7` 在此解析器里会成为 `(0,0)`，不能照搬。

```lua
local datePart, buildPart = version:match("^(%d+)%.(%d+)$")
if not datePart then
    datePart = version:match("^(%d+)$")
    buildPart = "0"
end
return tonumber(datePart) or 0, tonumber(buildPart) or 0
```

检测页 `RefreshStatuses`（342）以 T.Version 起步，在**所有已有版本（包括缓存）**中求最高版本，再 `DetermineStatus`（217）判断大于等于该最高版本为 latest，低于为 outdated。这不是从服务器或 GitHub 验证过的官方最新发布版本。

简体翻译来自 `STT_Locales/options/zhCN.lua` 第 902～905 行：latest=最新、outdated=过时、no_response=未响应、offline=离线。本文只记录 STT 的命名，SFD 必须改用本机检测基准和“与本机一致／需要更新／高于本机版本／版本格式未知”。

## 5. 扫描、自动回报和结果更新

检测页第 7～8 行 `QUERY_TIMEOUT=2.0`、`COOLDOWN_SECONDS=5.0`。StartScan 要求已组队、脱战、距离 lastScanTime 至少5秒。

每次启动重建 resultMap、sortedResults，采集名单、保存 currentScanID；在线非本机且有缓存者立即 ApplyVersion(...,true)；无版本在线者初始 no_response，离线者初始 offline，本机直接填版本。收集在线非本机 expected 后**发一次广播**，并不是逐个私聊查询。

通信层 `OnQuery` 自动回报，无需团员打开页面或点击按钮；`nextReplyTime` 是每个客户端全局5秒门限，不按发起者区分。因此两个团长同时查询时，后到的查询可能被这个客户端跳过，不能照搬为严格并行扫描方案。

回报进入检测页 `OnReply`，找到成员后 ApplyVersion→昵称→重算状态→排序→刷新UI。等待2秒后 `scanTimer` 回调置 isScanning=false，再汇总。结果可以在到达时立即显示，不必等超时。

按钮更新（835～858）：未组队/战斗/扫描中/冷却时禁用，扫描或冷却显示 scanning 文本；点击后另设5秒 `C_Timer.After` 刷新按钮；`OnShow` 重新评估。未看到此页实现明确的秒数倒计时。界面隐藏不取消扫描结果处理；`uiRefreshCb` 是当前渲染绑定，不等同于独立快照与完整事件清理方案。

## 6. 缓存和迟到消息的真实边界

`versionCache` 位于检测页局部变量（第 59 行附近），是本次客户端会话内表，不是带时间的持久化缓存。`ApplyVersion`（323）每次写 entry.version、fromCache，并把 fullName→version 存入缓存。未看到缓存 TTL、来源检测编号或记录时间。

StartScan 会把在线成员的缓存读入本轮 entry，并调用 RefreshStatuses，所以**即使本轮尚未回报，也可能统计为 installed/latest/outdated**。Tooltip 在 722 行附近用 `VERSION_CHECK_TOOLTIP_CACHED` 标记缓存，但主状态及 installed 统计仍可能让旧记录影响本轮判断。

检测页 `OnReply` 第 411～416 行的关联检查是条件式：

```lua
if currentScanID and payload.scanID
    and tostring(payload.scanID) ~= tostring(currentScanID) then
    return
end
```

因此有以下边界：

1. 非空且不等于本轮编号的回复被拒绝，包括昵称查询的 list-* 回报（已有 currentScanID 时）。
2. 缺失 scanID 的旧式回报可绕过上述条件；它不能证明属于本轮。
3. 没有 `isScanning` 或截止时间检查；与 currentScanID 相同的回复即使2秒后才到达，仍可修改当前结果和缓存。
4. 没有严格拒绝同成员重复回报；重复回报仍会 ApplyVersion 并重刷，后来的版本可能覆盖前一条。
5. 基于当前名单的通信检查与启动快照匹配之间，没有在此模块看到扫描期间进出队的完整处理；不能宣称有“已离队”和“新成员下次检测”语义。
6. 短字段 Q/R 确实可被当前接收分支解析，但未取得旧 STT 发布快照来证明某个具体旧版本曾发这些格式；**解析器兼容能力不等于有证据的历史版本协议**。

“未响应”只能说明未得到有效版本信息；未安装、未加载、无回报功能、通信失败、全局回复冷却都可能造成相同表现。不能从超时推导确定未安装。

## 7. SFD 应借鉴和必须改动的部分

可借鉴：主插件常驻轻量接收端；按需创建检测界面；一次团队广播查询；自动回报；TOC 为版本来源；完整跨服名关联；结果即时更新；脱战按钮门限与限流；自身版本直接读取。

SFD 必须调整：

- 使用独立 SFDVER 前缀，不监听或依赖 STTVER；不引用 STT/T.VersionUtil/T.Lite/Options/Locales。
- 本机检测基准：V0.7。TOC→T.version→界面与网络回报，只保留一个版本来源；不使用团队最高版本称“最新版”。
- 支持任意完整数字段并按数字比较，V0.10>V0.9；未知格式保留原文并标未知，不解析为0。
- 5秒窗口、期间按钮禁用并倒计时；扫描编号绑定发起者与本轮；严格截止时间、目标、名单、GUID和协议字段验证。
- 每轮清空回报；有回报才“已加载”；无回报“未响应”；离线和已离队独立显示。SFD 当前设计不使用版本缓存；若以后增加必须标“上次记录”和时间。
- 显式处理 PARTY、RAID、INSTANCE_CHAT；不要仅因检测页检查实例类别就假定通信通道正确。自动回报需按发起者限流，以允许多人同时检测；消息只走插件接口。
- 前缀注册与消息发送按当前客户端枚举结果处理；失败明确展示。客户端/服务器禁用通信时也不能将失败当成成员未安装。
- 显示角色-服务器、职业色、在线状态、实际版本和判断；进入/离开团队需保持本轮原始名单，新增成员下一轮检查；页面隐藏仍收尾，计时器取消且事件只注册一次。

## 8. SFD 历史兼容证据

可取得历史 SFD 包及源码审计记录保存为 `../audit/version_history_evidence.json`，包含包绝对路径、SHA256、TOC 版本、通信命中位置。已检查 V0.1、V0.2、V0.3、V0.4（p0_before）、V0.4.1-p0、V0.5（GitHub commit `d508deac146ffbef22228ea1138b5b29e270b757`）、V0.6，以及早期1.0.0-rc1/1.1.0-rc1与若干改动前备份。

这些样本没有 SendAddonMessage、RegisterAddonMessagePrefix、CHAT_MSG_ADDON 版本握手或上线版本广播。唯一相关发送是 WindOctagon 的 `SendChatMessage(TOKEN_PREFIX..idx,activeChannel())`，仅携带风向，不包含版本号；本地 T.version、诊断 SavedVariables 中 addonVersion 不会自动传给团长。

因此目前没有可接入的、有来源证据的旧版版本回复协议。不得构造“旧版兼容解析”再用人工造包宣称支持历史版本。旧版只能诚实显示未响应；未来若取得真实含版本的旧协议证据，再增加独立适配器，并区分无编号旧回报、本轮严格关联回报及历史缓存。

某些 V0.2/V0.3 包的 TOC 与 core/init.lua 内硬编码版本还不一致（详见证据 JSON），这进一步说明不能根据旧聊天风向或本地字串臆测远程发布版本。

## 9. 无 STT 源目录后的维护检查

本文包含：原路径/行号/版本/哈希；Q/R字段和转义；事件注册和加载入口；按钮→发送→回复→显示链；完整名处理与短名退路；版本解析/最高版本规则；2秒超时与5秒冷却；缓存、缺编号、迟到、重复、并发的限制；SFD 改造约束和历史协议证据。使用上述内容即可独立实现或排查 SFD 通信，不需要 STT 文件或 STT 运行时。

仍须游戏内多人实测：真实跨服名字规范、PARTY/RAID/INSTANCE_CHAT投递、当前服务器通信权限与枚举结果、多人同时扫描、离线/离队、真实延迟和5秒截止、40人列表与滚动/职业色。静态审计和离线模拟不证明上述多人运行结果。
