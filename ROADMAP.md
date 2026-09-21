# ROADMAP

## 当前阶段

- 当前代码位于 v0.2.0 之后的开发状态，核心按键映射、ATVV 语音链路与 macOS GUI 已在上游实现。
- 已安装并加载 BlackHole 2ch 0.7.1；MiRemote 到 BlackHole、网易叭哥说识别与文本回写已完成真实遥控器语音验收。
- 已完成首轮可行性研究与实施报告及 ATVV 真实语音验收；仍需补齐全部蓝牙按键与目标控制场景的真机证据。
- 本 fork 已接入 Harness 手动验证入口；Git Hooks 尚未安装，硬件与系统权限行为仍需真机验收。

## 进行中

- 按 `FIELD-TEST.md` 和 `TESTPLAN.md` 补齐其余遥控器按键、权限与打包验收证据。

## 最近完成

- 2026-09-21 23:02 修复语音流启动时异步清空导致首批 PCM 可能丢失的竞态，并把 GUI 输入增益偏好接入每次语音会话的 PCM 后处理链；本机增益设为 +6 dB，详见 `goals/20260921-2243-fix-blackhole-audio.md`。
- 2026-09-21 21:58 将完整 Git 项目提升到 `xiaomi-control` 根目录并移除多余子目录；完成 Harness 项目规范、结构化验证配置、固定验证器、手动 push 入口和历史大文件 baseline。
- 2026-09-21 21:46 将本地仓库的 `origin` 切换为 `maydaychen/mi_remote_control` fork，并保留原作者仓库为 `upstream`。
- 2026-09-21 21:13 通过 Homebrew Cask 安装 BlackHole 2ch 0.7.1，驱动已写入系统 HAL 插件目录。
- 2026-09-21 19:56 完成 `godarrenw/mi_remote_control` 源码、Release、相关 Issues 与上游 ATVV 参考项目调研，交付 `小米蓝牙遥控器控制Mac实施报告.html`。

## 最近验证

- 2026-09-21 23:02 真实遥控器语音经修复版 MiRemote 写入 BlackHole：独立 48 kHz 单声道采样得到两个有效人声段，较强一段 RMS -35.49 dBFS、峰值 -13.18 dBFS；网易叭哥说完成 11 字与 8 字两次转写并成功回写，未再出现 `NO_SPEECH_DETECTED`。
- 2026-09-21 22:57 执行 Harness task 模式验证：44 个维护源文件规模检查、`./build.sh` 和 `.build/miremote --self-test` 全部通过；保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-21 22:55 使用确定性 16 kHz／1 kHz PCM 经真实 `AudioBridge` 输出到 BlackHole 并双声道录回：左右声道峰值均为 -5.97 dBFS、RMS 均为 -12.04 dBFS，实时输出与采样率转换正常。
- 2026-09-21 21:58 从项目根目录执行 Harness 配置校验和 task 模式验证：44 个维护源文件完成规模检查，构建成功，内置自检返回 `SELF-TEST PASS`；保留 1 条既有 Swift 闭包捕获 warning。
- 2026-09-21 21:46 拉取 fork 的 `main` 后确认本地分支跟踪 `origin/main`，工作区干净；`origin/main` 与 `upstream/main` 均位于提交 `c2c9289`，无领先或落后提交。
- 2026-09-21 21:19 重启后通过 Core Audio API 确认 `BlackHole 2ch` 已加载，UID 为 `BlackHole2ch_UID`，输入与输出均为 2 通道，当前采样率为 48 kHz。
- 2026-09-21 21:13 核验 Homebrew Cask、`audio.existential.BlackHole2ch` 安装包和 `BlackHole2ch.driver` 均存在；重启前 `system_profiler` 尚未枚举 BlackHole，按安装器提示保留为待重启验证。
- 2026-09-21 19:56 对上游主分支提交 `c2c92899e6a8ecf9dbd85212a1ee2842b0343ec0` 执行 `./build.sh` 与 `.build/miremote --self-test`，构建成功并返回 `SELF-TEST PASS`；存在一条不阻断构建的闭包捕获 warning。
- 2026-09-21 19:56 在 Edge 以 1440×900 与 390×844 验收 HTML：页面无整体横向溢出，目录、主题、键盘焦点和容器内滚动正常，控制台 0 error／0 warning；打印媒体静态规则通过复核，实际打印预览因 Playwright 缓存权限问题未运行。
