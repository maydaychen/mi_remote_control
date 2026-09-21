# 修复 BlackHole 语音采样链路

## 目标

确认小米遥控器的语音能够由 MiRemote 正确写入 `BlackHole 2ch`，并由独立输入采样端获得有效、非静音的 PCM 音频。

## 已知证据

- 遥控器 ATVV 解码后的本地 WAV 为 16 kHz 单声道，持续约 3.5 秒，均方根约 -34.2 dBFS、峰值约 -8.4 dBFS，说明遥控器、蓝牙传输、ADPCM 解码和 PCM 后处理链路存在有效人声。
- 独立向 `BlackHole 2ch` 输出 1 kHz 正弦波并从其输入端采样，得到约 -26.0 dBFS 均方根、-21.1 dBFS 峰值，说明 BlackHole 驱动和回环本身有效。
- 网易叭哥说已选择 `BlackHole 2ch`，但会话日志显示 `maxAudioPeak=0.0000`、`activeAudioFrames=0`，故问题集中在 MiRemote 的 `AudioBridge → BlackHole` 输出段。

## 范围与边界

- 允许修改 `Sources/MiRemote/Audio/AudioBridge.swift` 及直接相关的自动化验证、项目进度文档。
- 只做最小音频链路修复，不改遥控器按键映射、输入法适配、配置语义或用户自建 profile。
- 不提交现有未跟踪的实施报告，不 push、不发布、不执行签名分发。
- 调试音频与探针文件只放在 `.tmp/fix-blackhole-audio/`，完成后删除本任务生成的临时文件。

## 施工清单

### 1. 独立诊断

- 执行者：`debugger` Agent，只读。
- 输入：本文件、`AudioBridge.swift`、相关调用点和测试文档。
- 输出：对采样率、节点连接格式、渲染回调和环形缓冲区消费速率的根因判断；不得修改工作区。
- 验收：结论包含可复现实验或明确的观测指标，并覆盖主要失败路径。

### 2. 可控回环复现

- 使用确定性 16 kHz PCM 信号复现当前 `AudioBridge` 的输出行为。
- 对比当前连接格式和候选修复，记录 BlackHole 输入端的采样时长、有效帧数、均方根与峰值。
- 验收：同一输入、同一设备、同一采样方法下，能够稳定区分失效实现与有效实现。

### 3. 最小修复与回归保护

- 只修改已经由证据确认的故障点。
- 为新增或更改的逻辑补充可重复验证，覆盖空缓冲、采样率转换和启停边界。
- 验收：`./build.sh`、`.build/miremote --self-test` 和 Harness task 验证全部通过。

### 4. BlackHole 集成验证

- 向修复后的真实 `AudioBridge` 输入确定性 PCM，并从 `BlackHole 2ch` 输入端独立采样。
- 验收：采样文件含持续有效的非零音频，频率和幅度与输入相符，不只有启动瞬态或静音。

### 5. 真机语音验收

- 启动修复后的 MiRemote，用户按住遥控器语音键说话 3～5 秒。
- 同时从 `BlackHole 2ch` 独立采样，并核对网易叭哥说的输入表现或日志。
- 验收：BlackHole 采样获得可信的人声时长和非零均方根／峰值；网易叭哥说不再出现该会话全零音频。若任一项缺证据，Goal 保持未完成。

## 交付结果

- 最小源代码修复及相关回归验证。
- `ROADMAP.md` 中记录实现和验证状态。
- 一次只包含本任务文件的本地 Git commit；不包含既有未跟踪文件。
- 最终明确区分代码实现、自动化验证、BlackHole 集成、真机语音、commit 与 push 状态。

## 当前状态

- 2026-09-21 22:43：已建立施工清单，进入独立诊断与可控回环复现。
- 2026-09-21 22:51：确定性 PCM 通过真实 `AudioBridge → BlackHole → 网易叭哥说`，叭哥说采得 `maxAudioPeak=0.4983`、`activeAudioFrames=121`，排除 BlackHole、声道和 16 kHz→48 kHz 转换失效。
- 2026-09-21 22:54：修复 `streamStarted()` 异步清空环形缓冲造成的首帧竞态，并接通原先只保存、不进入处理链的 GUI 输入增益；新增运行时增益回归断言。
- 2026-09-21 22:57：`./build.sh`、`.build/miremote --self-test` 和 Harness task 验证通过；确定性 BlackHole 双声道录回峰值均为 -5.97 dBFS。
- 2026-09-21 23:02：真实遥控器语音验收通过。独立 BlackHole 采样得到两个有效人声段，较强一段 RMS -35.49 dBFS、峰值 -13.18 dBFS；网易叭哥说完成 11 字与 8 字两次转写并成功回写，未出现 `NO_SPEECH_DETECTED`。Goal 完成。
