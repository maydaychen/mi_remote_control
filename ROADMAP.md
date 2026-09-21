# ROADMAP

## 当前阶段

- 当前代码位于 v0.2.0 之后的开发状态，核心按键映射、ATVV 语音链路与 macOS GUI 已在上游实现。
- 已安装并加载 BlackHole 2ch 0.7.1；MiRemote 到 BlackHole、网易叭哥说识别与文本回写已完成真实遥控器语音验收。
- 已完成首轮可行性研究与实施报告及 ATVV 真实语音验收；仍需补齐全部蓝牙按键与目标控制场景的真机证据。
- 本 fork 已接入 Harness 手动验证入口；Git Hooks 尚未安装，硬件与系统权限行为仍需真机验收。

## 进行中

- 按 `FIELD-TEST.md` 和 `TESTPLAN.md` 补齐其余遥控器按键、权限与打包验收证据。
- 已形成一秒测试音、可选音频路由和本地使用统计的 Goal 施工方案，待按 `goals/20260922-0109-voice-test-routing-usage-stats.md` 启动实现。

## 最近完成

- 2026-09-22 01:20 完成一秒测试音、自动／手动音频路由与本地按日使用统计的详细实施方案，明确数据口径、隐私边界、代码落点、分阶段任务和自动／BlackHole／真机验收标准；当前仅完成规划，功能尚未实现。
- 2026-09-22 01:11 将按键映射、场景配置、语音和通用页的标题与主操作移入 macOS 原生工具栏，删除重复的顶部占位和 AppKit 高度探针，页面内仅保留独立滚动正文。
- 2026-09-22 00:47 修复多屏环境下菜单栏状态浮窗未贴住实际点击图标的问题：左键路由改用事件触发的状态栏按钮，并按屏幕坐标归一化副屏浮窗的垂直锚点。
- 2026-09-22 00:44 将“退出当前 App”接入按键映射的系统功能目录，统一复用 `quit_frontmost_app` 动作发送 ⌘Q；系统功能浮层继续保留按住确认保护。
- 2026-09-22 00:14 为场景配置详情页接入右上角关闭按钮，点击后直接返回场景列表，并保留 Esc 退出方式。
- 2026-09-22 00:11 修复菜单栏状态浮窗因固定外宽过窄导致“暂停遥控”、说明文字和语音分段控件左侧裁切的问题，改为 320 pt 内容宽度加统一内边距。
- 2026-09-21 23:02 修复语音流启动时异步清空导致首批 PCM 可能丢失的竞态，并把 GUI 输入增益偏好接入每次语音会话的 PCM 后处理链；本机增益设为 +6 dB，详见 `goals/20260921-2243-fix-blackhole-audio.md`。
- 2026-09-21 21:58 将完整 Git 项目提升到 `xiaomi-control` 根目录并移除多余子目录；完成 Harness 项目规范、结构化验证配置、固定验证器、手动 push 入口和历史大文件 baseline。
- 2026-09-21 21:46 将本地仓库的 `origin` 切换为 `maydaychen/mi_remote_control` fork，并保留原作者仓库为 `upstream`。
- 2026-09-21 21:13 通过 Homebrew Cask 安装 BlackHole 2ch 0.7.1，驱动已写入系统 HAL 插件目录。
- 2026-09-21 19:56 完成 `godarrenw/mi_remote_control` 源码、Release、相关 Issues 与上游 ATVV 参考项目调研，交付 `小米蓝牙遥控器控制Mac实施报告.html`。

## 最近验证

- 2026-09-22 01:23 对照当前 `AudioBridge`、`DefaultInput`、`VoiceBridgeApp`、`MappingEngine`、`AppModel` 与语音页复核施工方案，文档结构／代码围栏／文件引用检查通过；沙箱外执行 Harness task 模式，44 个维护源文件规模检查、构建和内置自检全部通过，保留 1 条既有 Swift 闭包捕获 warning。本次未执行尚未实现功能的音频与真机验收。
- 2026-09-22 01:11 无引擎 UI 预览在副屏定向截图确认红框中的重复空白已删除，“按键映射”标题与说明居中使用原生工具栏空间，“识别按键”图文按钮固定在右侧；构建与内置自检通过。
- 2026-09-22 00:47 Harness task 模式通过：44 个维护源文件规模检查、构建和内置自检全部成功；在纵向偏移 37 pt 的副屏点击完整功能实例状态图标后，截图确认浮窗箭头贴住菜单栏底边，保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-22 00:44 Harness task 模式通过：44 个维护源文件规模检查、构建和内置自检全部成功；确认动作摘要与系统浮层目录自检覆盖 `quit_frontmost_app`，未执行会真实退出前台应用的破坏性端到端触发，保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-22 00:14 Harness task 模式通过：44 个维护源文件规模检查、构建和内置自检全部成功；关闭动作已接入详情弹窗的 `detailProfile = nil` 路径，保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-22 00:11 Harness 配置校验与 task 模式通过：44 个维护源文件规模检查、构建和内置自检全部成功；重启完整模式后实测菜单栏浮窗，标题、说明及三个语音选项完整显示且左对齐正常，保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-21 23:02 真实遥控器语音经修复版 MiRemote 写入 BlackHole：独立 48 kHz 单声道采样得到两个有效人声段，较强一段 RMS -35.49 dBFS、峰值 -13.18 dBFS；网易叭哥说完成 11 字与 8 字两次转写并成功回写，未再出现 `NO_SPEECH_DETECTED`。
- 2026-09-21 22:57 执行 Harness task 模式验证：44 个维护源文件规模检查、`./build.sh` 和 `.build/miremote --self-test` 全部通过；保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-21 22:55 使用确定性 16 kHz／1 kHz PCM 经真实 `AudioBridge` 输出到 BlackHole 并双声道录回：左右声道峰值均为 -5.97 dBFS、RMS 均为 -12.04 dBFS，实时输出与采样率转换正常。
- 2026-09-21 21:58 从项目根目录执行 Harness 配置校验和 task 模式验证：44 个维护源文件完成规模检查，构建成功，内置自检返回 `SELF-TEST PASS`；保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-21 21:46 拉取 fork 的 `main` 后确认本地分支跟踪 `origin/main`，工作区干净；`origin/main` 与 `upstream/main` 均位于提交 `c2c9289`，无领先或落后提交。
- 2026-09-21 21:19 重启后通过 Core Audio API 确认 `BlackHole 2ch` 已加载，UID 为 `BlackHole2ch_UID`，输入与输出均为 2 通道，当前采样率为 48 kHz。
- 2026-09-21 21:13 核验 Homebrew Cask、`audio.existential.BlackHole2ch` 安装包和 `BlackHole2ch.driver` 均存在；重启前 `system_profiler` 尚未枚举 BlackHole，按安装器提示保留为待重启验证。
- 2026-09-21 19:56 对上游主分支提交 `c2c92899e6a8ecf9dbd85212a1ee2842b0343ec0` 执行 `./build.sh` 与 `.build/miremote --self-test`，构建成功并返回 `SELF-TEST PASS`；存在一条不阻断构建的闭包捕获 warning。
- 2026-09-21 19:56 在 Edge 以 1440×900 与 390×844 验收 HTML：页面无整体横向溢出，目录、主题、键盘焦点和容器内滚动正常，控制台 0 error／0 warning；打印媒体静态规则通过复核，实际打印预览因 Playwright 缓存权限问题未运行。
