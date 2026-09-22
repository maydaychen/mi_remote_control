# 遥键 RemoKey 项目执行规范

遥键（RemoKey）将小米蓝牙遥控器 2 Pro 接入 macOS，提供按键映射、语音输入和 App 控制能力。项目使用 Swift 6，目标平台为 macOS 14 及以上，运行时不引入第三方依赖；Swift 模块与源码目录继续使用历史内部名称 `MiRemote`。

## Harness 路由

- 非平凡任务先读取本文件，再按需读取 `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Harness/Harness/AGENTS.md` 及其窄范围规则。
- Harness Profile 检测当前未识别出适用 Profile；本仓库是单根 Swift Package，不套用 iOS／SwiftUI／XcodeGen 规则。
- `.harness/verification.json` 是验证配置权威源；现有 CI 仍以 `.github/workflows/ci.yml` 为权威，不因本地 Harness 初始化而改变。

## 目录与权威源

- `Sources/MiRemote/`：应用源码；`App/Contracts.swift` 保存跨模块协议与核心 Codable 模型。
- `Resources/`：CLI 所需 Info.plist、默认配置与资源。
- `scripts/`：打包、签名和分发检查脚本。
- `build.sh`：本地与 CI 的构建权威入口；不要改用 `swift build`。
- `README.md`：当前功能、安装和使用说明；`HANDOFF.md` 与实际代码是当前文件结构事实源。
- `DESIGN.md`：设计原理与取舍；其中旧文件地图不作为当前结构事实。
- `TESTPLAN.md` 与 `FIELD-TEST.md`：自动化、半自动和真机验收范围。
- `ROADMAP.md`：当前项目进度、最近完成与验证记录。
- `.tmp/`：外部检出、截图、编译缓存和其他可重建临时材料，不纳入 Git。

## 构建与测试

```bash
./build.sh
.build/miremote --self-test
python3 scripts/harness/verify.py --repo . --mode task
```

- `build.sh` 使用 `swiftc` 直编并嵌入 `Resources/Info-cli.plist`；缺少该 plist 时，CoreBluetooth 可能被 TCC 终止。
- `--self-test` 是唯一完整自动化测试入口，必须全绿；没有按测试名筛选的机制。
- 修改打包脚本后运行 `bash -n scripts/*.sh`；发布或真机行为仍按 `TESTPLAN.md` 和 `FIELD-TEST.md` 单独验收。

<!-- HARNESS_VERIFICATION_START -->

## Harness 验证

- 验证事实源：`.harness/verification.json`。
- 固定入口：`scripts/verify-before-push.sh`。
- Profiles：待确认。
- Adapters：无。
- 文件规模门禁：超过 500 行警告，超过 1000 行失败。
- `.` 检查：source-file-lines, build, self-test。

<!-- HARNESS_VERIFICATION_END -->

## 实现不变量

- 按键 HID 与语音 ATVV 是两条独立链路，不得互相依赖。
- 不重新引入 macOS 用户态 seize 蓝牙 HID 键盘的路径；返回键 usage `0xF1` 继续由 IOHID 监听。
- 进程退出必须清空本程序安装的 `hidutil` 映射，避免污染真实键盘。
- 基础态方向键、返回键与 OK 键保护逻辑变更前，先核对 `MappingEngine`、提示条和内置 profile 的一致性。
- 配置优先级保持为 CLI 标志、`config.json`、内置默认；默认配置语义变化时递增 `MappingConfig.currentVersion` 并补充迁移，不能改写用户自建 profile。
- 涉及签名时保持固定 bundle id `com.remokey.controller`：本机开发包使用团队 `3YT2ZK3Z94` 的 `Apple Development`，站外正式分发只接受同团队的 `Developer ID Application`、Hardened Runtime、安全时间戳与 Apple 公证票据；缺少任一条件不得静默回退自签名或 ad-hoc。旧 bundle id `com.miremote.controller` 仅用于偏好迁移，不得重新作为产物身份。

## 文件规模治理

- 人工维护的 Swift 源文件超过 500 行警告，超过 1000 行失败。
- `.harness/file-lines-baseline.json` 仅冻结初始化时已超过 1000 行的历史文件；文件缩减至上限内后删除对应 baseline，不能为新文件或新增代码扩大 baseline。
- 排除固定 Harness 验证器、Git 元数据和构建／分发产物。

## Git 与交付边界

- 默认分支为 `main`；提交信息使用中文并遵循既有提交风格及 Harness Git 规范。
- 本地验证、commit、push、GitHub Actions、Release、签名包和真机验收是不同状态，分别报告。
- `scripts/verify-before-push.sh` 是手动入口；本次初始化未安装 Harness Git Hooks，不得声称已启用自动门禁。
- 未经明确授权，不 push、不创建 Release、不修改上游仓库，也不执行签名或正式分发。

## 真机验证边界

- 构建和自检不能证明蓝牙事件、ATVV 音频、BlackHole 路由、TCC 授权、Secure Input 或真实按键映射有效。
- 涉及硬件、系统权限、输入法、音频或签名的行为变更，必须按 `FIELD-TEST.md` 或 `TESTPLAN.md` 留下单独真机证据。
- 报告必须区分源码或官方资料确认的事实、基于代码的推断，以及需要真机验证的事项。
- 不在源码、报告、配置或日志中保存账号、Token、Cookie、蓝牙密钥、家庭网络地址等敏感信息。
