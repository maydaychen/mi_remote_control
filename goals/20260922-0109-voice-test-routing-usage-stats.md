# 语音测试音、可选音频路由与本地使用统计实施方案

## 文档状态

- 状态：待实施；本文件是后续 Goal 的施工事实源，本轮不实现功能代码。
- 创建时间：2026-09-22 01:20（北京时间）。
- 目标版本：当前 `main` 后续开发版本，不改变现有 ATVV／HID 双链路和零第三方运行时依赖约束。
- Goal 启动方式：后续以本文件作为施工清单创建 Goal；三个功能在同一 Goal 内按依赖顺序完成，不拆成互相不可验收的半成品。

## 1. 目标与最终用户效果

本次实现三个彼此关联、但职责清晰的能力：

1. **一秒测试音**：用户不必先拿遥控器说话，点击一次即可把确定性测试音写入当前语音输出设备，用来判断 BlackHole 与语音工具的收音链路是否正常。
2. **可选音频路由模式**：保留当前“语音时自动切换系统默认输入，结束后还原”的省心模式，同时允许用户选择“MiRemote 不改系统默认输入，由语音工具固定选择 BlackHole”。
3. **本地使用统计**：按天展示遥控动作触发次数、有效语音会话次数与时长、测试音次数，帮助用户知道遥控器是否真正成为日常工作流的一部分。

用户完成本次 Goal 后应能看到以下效果：

- 语音页新增“音频路由与测试”区域，可选择“自动切换”或“手动选择 BlackHole”，并可点击“播放 1 秒测试音”。
- 自动切换模式下，测试音或遥控器语音开始时临时把系统默认输入切到 BlackHole，结束后恢复原设备；手动模式下系统默认输入从始至终不变。
- 测试音播放期间不触发豆包、Typeless、superwhisper 等语音工具的快捷键，不切换输入法，也不伪造一次语音会话。
- 侧栏新增“统计”页，默认展示今日数据、近 7 天趋势和按键使用分布；退出并重启 MiRemote 后数据仍存在。
- 所有统计仅保存在本机，不联网、不保存录音、识别文字、快捷键内容、Shell 内容或前台 App 名称。

## 2. 范围与非目标

### 2.1 本 Goal 包含

- 生成并输出 1 秒确定性 PCM 测试音。
- 自动／手动两种系统默认输入路由策略及 UI 设置。
- 本地按日聚合、持久化、展示和清空使用统计。
- 相关纯逻辑自检、音频集成验证、真机验收、README／TESTPLAN／ROADMAP 状态同步。
- 一次只包含本 Goal 文件的本地 Git commit；不 push、不签名、不发布。

### 2.2 本 Goal 不包含

- 不实现云同步、账号、排行榜、遥测上报或任何远端 Analytics。
- 不保存原始按键事件流水、语音 PCM、识别文本、宏文本、Shell 命令或前台 App 使用历史。
- 不开发新的虚拟声卡驱动，不替换 BlackHole，不引入第三方依赖。
- 不把第三方语音工具“出现文字”当成完全可自动化的断言；目标 App 的最终识别仍按真机人工步骤验收。
- 不新增语音工具预设向导；该能力可在本 Goal 完成后另立任务。

## 3. 现状与代码落点

现有结构可以直接承载这三个功能，不需要重做语音架构：

- `Sources/MiRemote/Audio/AudioBridge.swift` 已能把 16 kHz、Int16、单声道 PCM 写到 BlackHole，并处理启动、排空、停止和首帧竞态。
- `Sources/MiRemote/Audio/DefaultInput.swift` 已提供默认输入设备查询、切换与幂等还原。
- `Sources/MiRemote/App/AppServices.swift` 中的 `VoiceBridgeApp` 已在首个真实音频帧到达时才切麦克风和触发语音工具，可继续复用这条“幽灵会话无副作用”边界。
- `Sources/MiRemote/UI/AppModel.swift` 已用 `UserDefaults` 管理语音模式与增益等 App 级偏好。
- `Sources/MiRemote/UI/VoicePage.swift` 已有 BlackHole 状态、链路自检和实时电平表，是路由与测试音的正确入口。
- `Sources/MiRemote/Mapping/MappingEngine.swift` 的 `perform(_:key:isHold:)` 是“物理操作已经解析为逻辑动作”的统一入口，适合记录动作触发次数，而不是在两条 HID 事件来源上重复计数。
- `Sources/MiRemote/UI/RootView.swift` 维护设置侧栏，可增加独立统计页。
- `Sources/MiRemote/App/SelfTest.swift` 是完整自动化入口；新增纯逻辑检查应由相关类型的 `selfCheck()` 接入，而不是扩大单个 UI 文件。

测试音需要知道真实启动结果，而现有 `PCMSink.streamStarted()` 没有返回值、`AudioBridge` 会在内部记录启动错误。实施时应为 `AudioBridge` 增加一个不改变 `PCMSink` 契约的内部 `startStream(sampleRate:) -> Result<Void, AudioBridgeError>`；常规 `streamStarted()` 继续调用它并记录错误，测试音服务则读取结果并映射为明确的 UI 状态。

## 4. 关键产品与技术决策

### 4.1 测试音的定义

测试音采用以下固定参数，保证每次结果可比较：

| 参数 | 固定值 | 理由 |
| --- | --- | --- |
| 波形 | 正弦波 | 频谱单一，便于录回检测 |
| 频率 | 1 kHz | 常见音频测试频率，易于自动判定 |
| 源采样率 | 16 kHz | 与 ATVV 解码输出一致，覆盖真实转换路径 |
| 声道 | 单声道 | 与遥控器语音一致 |
| 时长 | 1.0 秒 | 足够观察电平，不打扰正常使用 |
| 峰值 | -18 dBFS，容差 ±1 dB | 有明显电平且保留安全余量 |
| 淡入／淡出 | 各 20 ms | 避免首尾突变造成爆音 |

测试音必须走真实 `AudioBridge → voiceOutputDevice` 路径，不能只在 UI 中模拟电平。播放过程中：

- 不调用 `VoiceTrigger.begin/end`。
- 不修改输入法。
- 不增加语音会话次数，只增加测试音次数。
- 若真实遥控器语音正在进行，返回“语音使用中，请稍后再试”，不并发占用同一虚拟声卡路径。
- 输出设备不存在或引擎启动失败时显示可操作错误，不记录成功次数。

### 4.2 音频路由模式

新增 `VoiceInputRoutingMode`：

```swift
enum VoiceInputRoutingMode: String, CaseIterable {
    case automatic
    case manual
}
```

语义固定如下：

| 语音来源 | 路由模式 | MiRemote 行为 |
| --- | --- | --- |
| 遥控器麦克风 | `automatic` | 首个有效音频帧到达后调用 `DefaultInput.engage()`；结束后延迟 1.2 秒还原 |
| 遥控器麦克风 | `manual` | 始终不调用 `DefaultInput.engage/restore`；要求目标语音工具固定选择 BlackHole |
| Mac 麦克风 | 任意 | 不切系统默认输入；路由选择器禁用并解释“仅对遥控器麦克风生效” |
| 关闭 | 任意 | 不产生语音路由行为 |

默认值为 `automatic`，保证升级后行为与当前版本一致。该值属于 App 级运行偏好，使用 `UserDefaults` 保存，不写进按键映射 `config.json`，因此无需递增 `MappingConfig.currentVersion`。

`AppModel.applyVoiceMode()` 不再只按 `voiceMode` 决定 `switchInput`，而是使用下列真值表：

```text
switchInput = voiceMode == remoteMic && voiceRoutingMode == automatic
doubao      = voiceMode != off
```

测试音遵循同一套路由模式：自动模式允许临时切换并还原默认输入；手动模式保证系统默认输入不变。

测试音与真实语音共享一个轻量 `AudioActivityCoordinator`，状态仅允许 `idle`、`testTone`、`remoteVoice` 三选一。测试音开始时若处于 `remoteVoice` 则拒绝；真实语音开始时若处于 `testTone`，先取消测试音、还原它临时切换的默认输入，再启动真实语音。这样“真实语音优先”由代码状态机保证，不依赖 UI 按钮禁用。

### 4.3 使用统计的口径

统计页必须区分“触发”与“成功”：MiRemote 能确认动作已进入执行器，但多数 macOS／第三方 App 动作没有成功回执。因此 UI 使用“遥控动作”或“动作触发”，不得写成“成功操作”。

按天记录以下聚合字段：

| 字段 | 计数时机 | 不计入的情况 |
| --- | --- | --- |
| `actionTriggers` | `MappingEngine.perform` 接收到非空动作并准备执行时，每个解析完成的 tap／hold／double／gesture 计 1 次 | 原始 keyDown／keyUp、暂停态事件、没有绑定的操作、浮层内仅用于移动焦点的按键 |
| `actionsByKey` | 与 `actionTriggers` 同时，按 `RemoteKey.rawValue` 聚合 | 不保存 App、动作参数或文本内容 |
| `actionsByKind` | 按 `keyStroke/system/openApp/window/tab/focus/mouse/macro/overlay/layer/other` 等粗粒度分类 | 不保存 bundle id、Shell 命令和宏步骤 |
| `voiceSessions` | 每次 ATVV START 后首次得到非空解码 PCM 时计 1 次 | 只有 START／STOP 而没有音频帧的幽灵会话、测试音 |
| `voiceSampleCount` | 把实际写入 sink 的 16 kHz PCM 样本数累加 | 测试音样本 |
| `testToneCount` | 测试音确认启动并写入 AudioBridge 后计 1 次 | busy、设备缺失、启动失败 |

语音时长由 `voiceSampleCount / 16000.0` 得出，不使用墙上时钟。这样即使蓝牙停流回调延迟或 App 在会话末尾退出，统计仍对应真正处理的音频量。

首版只保留最近 90 个自然日。日期桶使用事件发生时的本机日历 `yyyy-MM-dd`；时区变化不追溯重分历史数据。

### 4.4 隐私与故障隔离

- 数据文件：`~/Library/Application Support/MiRemote/usage-stats.json`。
- schema 从 `version: 1` 开始，写入采用临时文件加原子替换。
- 保存由专用串行队列完成；高频动作 1 秒 debounce，App 正常退出时强制 `flush()`。
- 文件缺失视为空统计；解析失败保留原文件并以空统计继续运行，日志给出明确错误，不能阻断 HID、ATVV、GUI 或退出清理。
- 设置中提供“记录本地使用统计”开关，默认开启。关闭后不再新增数据，但不自动删除历史；“清空统计”需二次确认，确认后删除统计文件并立即刷新页面。
- 不发送网络请求；实现中不得引入 URLSession、第三方分析 SDK 或设备／用户标识符。

## 5. 目标代码结构

建议新增两个窄职责文件，避免继续放大已经接近规模警告的核心文件：

```text
Sources/MiRemote/
├── Audio/
│   └── AudioTestTone.swift          # 纯音生成 + 测试音播放协调
├── Usage/
│   └── UsageStatistics.swift        # 数据模型、聚合、存储、快照、自检
└── UI/
    └── StatisticsPage.swift         # 今日摘要、7 日趋势、按键分布、隐私与清空
```

预计修改：

- `Sources/MiRemote/UI/AppModel.swift`：新增路由偏好、统计开关、统计快照与刷新方法。
- `Sources/MiRemote/App/AppServices.swift`：持有统计 store 和测试音服务；在语音帧路径记录会话／样本；停止时 flush。
- `Sources/MiRemote/Mapping/MappingEngine.swift`：新增可注入、默认为空的动作记录回调，在统一 `perform` 入口上报 key 与动作粗分类。
- `Sources/MiRemote/UI/VoicePage.swift`：新增路由选择、动态说明、测试音按钮和结果状态。
- `Sources/MiRemote/UI/RootView.swift`：新增“统计”侧栏项与页面路由。
- `Sources/MiRemote/UI/GUIAppDelegate.swift`：把统计快照变化和测试音服务接入 `AppModel`，退出路径 flush。
- `Sources/MiRemote/App/SelfTest.swift`：接入新增类型的纯逻辑自检结果。
- `README.md`、`TESTPLAN.md`、`ROADMAP.md`：在实现完成后同步真实状态和验证证据。

不得为了统计修改 `Action` Codable 格式，也不得把统计字段加入用户的按键映射配置。

## 6. 接口草案

以下是实施时应保持的职责边界，不要求逐字照搬命名：

```swift
struct UsageDay: Codable, Equatable {
    var date: String
    var actionTriggers: Int
    var actionsByKey: [String: Int]
    var actionsByKind: [String: Int]
    var voiceSessions: Int
    var voiceSampleCount: Int64
    var testToneCount: Int
}

struct UsageSnapshot: Equatable {
    var today: UsageDay
    var recentDays: [UsageDay]
    var last7ActionTriggers: Int
    var last7VoiceSessions: Int
    var last7VoiceSeconds: Double
}

protocol UsageRecording: AnyObject {
    func recordAction(key: RemoteKey, kind: UsageActionKind, at date: Date)
    func beginVoiceSessionIfNeeded(id: UInt64, at date: Date)
    func recordVoiceSamples(_ count: Int, sessionID: UInt64, at date: Date)
    func recordTestTone(at date: Date)
    func snapshot(now: Date) -> UsageSnapshot
    func clear()
    func flush()
}

enum TestToneResult: Equatable {
    case started
    case busy
    case outputDeviceMissing
    case routingFailed
    case engineFailed(String)
}
```

测试应通过注入 `Date`／`Calendar`／临时文件 URL 驱动，不直接依赖当前日期或真实 Application Support 目录。

## 7. UI 方案

### 7.1 语音页

在“输入模式”之后、“按 App 的语音快捷键”之前增加 `SettingsGroup(title: "音频路由与测试")`：

- “系统默认输入”两项选择：
  - **自动切换并还原（推荐）**：说明“开始说话时临时切到 BlackHole，结束后恢复原麦克风”。
  - **不修改系统默认输入**：说明“请在豆包／Typeless／superwhisper 等目标工具中固定选择 BlackHole”。
- “播放 1 秒测试音”按钮：
  - 空闲：`播放测试音`。
  - 播放中：显示 `ProgressView`，按钮禁用，文本“正在发送 1 kHz 测试音…”。
  - 完成：短暂显示“测试音已发送，请观察语音工具的麦克风电平”。
  - 失败：就地显示原因与下一步，不用模态警告打断设置流程。
- 当语音来源不是“遥控器麦克风”时，路由选择器与测试音仍可查看但测试音按钮禁用，并说明测试仅针对虚拟声卡链路。
- 原“豆包麦克风设置”说明根据路由模式变化：手动模式强调目标工具固定选择 BlackHole；自动模式不再要求用户同时完成互相矛盾的设置。

### 7.2 统计页

侧栏在“语音”和“通用”之间新增“统计”，图标使用 `chart.bar.xaxis`。页面沿用 `SettingsPageLayout`、`SettingsGroup`、现有 spacing／radius／颜色 token，不另造视觉体系。

页面结构：

1. **今日概览**：3 个并列摘要块，分别显示“遥控动作”“语音会话”“语音时长”；测试音次数以次级文字显示，不与真实语音混淆。
2. **近 7 天趋势**：每天一根动作次数柱，悬停或下方标签显示日期与次数；没有数据时展示空状态“使用遥控器后，这里会按天显示趋势”。
3. **今日按键分布**：按次数降序显示前 5 个物理键，名称复用 `KeyDisplay.name(_:)`；其余合并为“其他”。
4. **隐私与数据**：说明“数据仅保存在这台 Mac”，提供记录开关和“清空统计…”按钮。清空必须用确认弹窗，并明确不可恢复。

统计页面不要展示 App 排名、原始动作内容或逐次时间线，避免把轻量本地统计变成行为追踪系统。

## 8. 分阶段施工清单

### T0. 基线与工作区保护

- 目标：确认当前分支、既有未提交改动和三项验证基线。
- 输入：本文件、`AGENTS.md`、`.harness/verification.json`。
- 允许：只读检查、构建、自检、Harness task。
- 禁止：暂存或改写任务开始前已经存在的 UI 改动与未跟踪报告。
- 验收：记录基线结果；若基线已失败，先判断是否与本 Goal 无关，不用扩大范围掩盖失败。

### T1. 本地统计核心

- 目标：实现可注入日期与存储 URL 的数据模型、90 日聚合、原子保存、快照、关闭记录与清空。
- 依赖：T0。
- 允许修改：新增 `UsageStatistics.swift`，以及接入自检所需的最小文件。
- 禁止修改：HID／ATVV 行为、UI。
- 自动验收：覆盖同日累加、跨日分桶、90 日裁剪、禁用不记录、重启读回、损坏 JSON 不崩溃、清空后文件与快照归零。

### T2. 统计事件接线

- 目标：在逻辑动作入口记录动作，在首个非空 PCM 帧记录语音会话并累计真实样本数，在测试音成功启动后记录测试次数。
- 依赖：T1；测试音计数钩子可先定义、在 T4 接通。
- 允许修改：`MappingEngine.swift`、`AppServices.swift` 及直接相关自检。
- 禁止修改：动作 Codable 格式；不得在 IOHID 与 event tap 两条原始通道各记一次。
- 自动验收：一次 tap／hold／double／gesture 各只增加 1；无绑定和暂停事件不增加；START→STOP 零帧会话为 0；同一会话多帧只增加 1 次会话、样本数正确累加。

### T3. 可选音频路由

- 目标：新增持久化路由偏好，并让遥控器语音与测试音共同遵循它。
- 依赖：T0。
- 允许修改：`AppModel.swift`、`AppServices.swift`、`VoicePage.swift` 及直接相关自检。
- 禁止修改：`MappingConfig.currentVersion`、默认声卡名称、1.2 秒语音收尾策略。
- 自动验收：四种 `voiceMode × routingMode` 关键组合与默认迁移行为全部可断言；旧用户首次升级仍为 automatic。
- 真机验收：见第 9.2 节。

### T4. 一秒测试音

- 目标：生成固定信号并通过真实 AudioBridge 写入 BlackHole，提供 busy／缺设备／路由失败／播放完成状态。
- 依赖：T3。
- 允许修改：新增 `AudioTestTone.swift`、`AppServices.swift`、`AppModel.swift`、`VoicePage.swift` 及直接相关自检。
- 禁止修改：ATVV 协议、ADPCM 解码器、VoiceTrigger 快捷键时序。
- 自动验收：样本数、频率、峰值、淡入淡出、状态互斥和失败结果均有确定性断言。
- 集成验收：见第 9.2 节。

### T5. 统计页

- 目标：把统计快照以今日、7 天趋势、按键分布展示，并提供关闭记录与二次确认清空。
- 依赖：T1、T2、T4。
- 允许修改：新增 `StatisticsPage.swift`、修改 `RootView.swift`、`AppModel.swift` 和必要设计 token 使用点。
- 禁止修改：现有四个设置页的信息架构；不得覆盖任务开始前的 UI 改动。
- 验收：有数据、无数据、统计关闭、清空确认和窗口窄至项目最小宽度时均无裁切或横向溢出；VoiceOver 能读出卡片标题与值。

### T6. 文档、全量验证与交付

- 目标：同步当前真实功能与验证边界，完成自动化、音频集成和真机验收，形成内聚 commit。
- 依赖：T1～T5 全部完成。
- 允许修改：`README.md`、`TESTPLAN.md`、`ROADMAP.md` 和本文件状态记录。
- 禁止：push、Release、签名分发；没有证据时不得把人工步骤标为已通过。
- 交付：源代码、测试、更新后的项目文档、一次本地 commit，以及清晰区分的自动／集成／真机验证结果。

## 9. 验收标准

### 9.1 自动化验收

以下命令全部通过：

```bash
./build.sh
.build/miremote --self-test
python3 scripts/harness/verify.py --repo . --mode task
```

新增逻辑必须至少覆盖：

- 测试音为 16000 个样本，时长 1 秒，频率为 1 kHz，峰值处于 -19～-17 dBFS，首尾淡入淡出无突变。
- `automatic` 与 `manual` 的路由真值表正确；旧偏好缺失时默认 `automatic`。
- 测试音 busy、输出设备缺失、路由失败不会触发输入法／语音工具快捷键，也不增加成功测试次数。
- 统计同日累计、跨日分桶、90 日裁剪、重启读回、损坏文件、禁用记录、清空和 flush 均符合第 4.3～4.4 节。
- 一次逻辑动作只记 1 次；幽灵语音会话不计数；一个有效会话不因多帧重复增加会话数。

### 9.2 BlackHole 集成与真机验收

#### A. 自动路由测试音

前置：BlackHole 2ch 已安装，系统默认输入不是 BlackHole。

1. 选择“遥控器麦克风”与“自动切换并还原”。
2. 独立记录系统默认输入设备 ID。
3. 点击“播放 1 秒测试音”，同时从 BlackHole 2ch 输入端录回。
4. 播放结束后再次读取系统默认输入设备 ID。

通过标准：

- 播放期间默认输入切到 BlackHole，结束后 1.5 秒内恢复原设备。
- 录回信号主频为 1 kHz ±20 Hz，有效时长 0.9～1.1 秒，峰值位于 -21～-15 dBFS。
- 没有输入法切换、语音工具快捷键触发或残留修饰键。
- 统计页测试音次数准确增加 1，语音会话次数不变。

#### B. 手动路由测试音

前置：目标语音工具手动选择 BlackHole 2ch，系统默认输入保持为真实麦克风。

通过标准：

- 点击测试音前、中、后的系统默认输入设备 ID 完全相同。
- BlackHole 独立录回与目标工具电平都能观察到测试音。
- 统计只增加 1 次测试音。

#### C. 两种路由的真实遥控器语音

1. automatic：按住遥控器说话 3～5 秒，确认默认输入临时切换并还原，目标工具得到文字。
2. manual：目标工具固定选择 BlackHole，按住遥控器说话 3～5 秒，确认系统默认输入不变，目标工具得到文字。

通过标准：

- 两种模式各完成至少 2 次连续会话，无一次全零音频或默认输入残留。
- 每次有效会话只增加 1 次；累计语音时长与实际说话总时长误差不超过 15%。
- START／STOP 零帧探针不会增加会话数。

#### D. 统计持久化与精确计数

执行一组固定动作：短按 Home 2 次、短按 TV 2 次进出控制模式、完成 2 次有效语音、播放 1 次测试音。

通过标准：

- 今日动作触发次数净增 4；Home 与 TV 各增 2。
- 今日语音会话净增 2；测试音净增 1。
- 重启 App 后数值不变。
- 关闭统计后重复同一组操作，数值不变；重新开启后恢复计数。
- 点击“清空统计…”但取消时数据不变；确认后页面归零且重启仍为空。

### 9.3 UI 与可访问性验收

- 路由选项、测试音状态和错误说明在浅色／深色模式下可读。
- 760×560 项目最小窗口内，语音页与统计页可纵向滚动，无整体横向溢出。
- 键盘可聚焦路由选项、测试音按钮、统计开关和清空按钮；焦点环清晰。
- VoiceOver 读数包含“今日遥控动作 N 次”“今日语音 N 次”“语音时长 N 分 N 秒”，趋势图提供等价文本摘要。
- Reduce Motion 下不依赖动画表达播放完成或统计变化。

## 10. 完成定义

只有同时满足以下条件，Goal 才能标记完成：

- T1～T6 全部完成，没有以占位 UI 或日志代替真实功能。
- 三条自动化命令全部通过，且未扩大 Harness 历史大文件 baseline。
- 自动／手动路由、测试音录回、真实遥控器语音和统计精确计数均留下证据。
- README 只描述已经实现的当前能力；TESTPLAN 增加可重复步骤；ROADMAP 记录实现与验证状态。
- 本文件“文档状态”更新为已完成，并附实现 commit 与验证摘要。
- 本地 commit 只包含本 Goal 相关文件，不包含用户已有 UI 改动和未跟踪 HTML；未获得额外授权时保持未 push、未发布。

## 11. 风险与回退

| 风险 | 控制方式 | 回退方式 |
| --- | --- | --- |
| 测试音与真实语音并发争用 AudioBridge／DefaultInput | 单一 busy 状态；真实语音优先，测试音直接拒绝 | 关闭测试音入口不影响既有语音链路 |
| 手动模式配置错误导致目标工具无声 | UI 明示目标工具必须选择 BlackHole；提供测试音即时检查 | 切回默认 automatic 即恢复当前行为 |
| 高频统计写盘 | 串行队列 + 1 秒 debounce + 退出 flush | 可关闭统计；统计失败不得影响控制功能 |
| 两条 HID 事件路径重复计数 | 只在 `MappingEngine.perform` 记录逻辑动作 | 移除记录回调即可恢复，不触碰 HID 解析 |
| 统计文件损坏 | 原子写入、解析失败 fail-open、保留原文件 | 删除或清空独立统计文件，不影响 `config.json` |
| UI 文件存在并行改动 | 实施前检查 diff，使用窄补丁，不格式化无关区域 | 冲突时停止覆盖并重新基于最新文件落点调整 |
