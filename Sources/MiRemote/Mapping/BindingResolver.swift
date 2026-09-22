import Foundation

/// 配置继承与基础态保护的共同事实源；编辑器保留原始槽位，速查与执行使用有效值。
enum BindingResolver {
    static func merge(global: KeyBinding?, overlay: KeyBinding?) -> KeyBinding? {
        guard let overlay else { return global }
        guard var result = global else { return overlay }
        if let value = overlay.tap { result.tap = value }
        if let value = overlay.hold { result.hold = value }
        if let value = overlay.double { result.double = value }
        if let values = overlay.gesture { result.gesture = (result.gesture ?? [:]).merging(values) { _, new in new } }
        if let values = overlay.layers { result.layers = (result.layers ?? [:]).merging(values) { _, new in new } }
        return result
    }

    static func merged(_ config: MappingConfig, profile: String, key: RemoteKey) -> KeyBinding? {
        merge(global: config.profiles["global"]?[key.rawValue],
              overlay: profile == "global" ? nil : config.profiles[profile]?[key.rawValue])
    }

    static let arrows: [RemoteKey: String] = [
        .up: "up_arrow", .down: "down_arrow", .left: "left_arrow", .right: "right_arrow",
    ]

    static func tap(key: RemoteKey, binding: KeyBinding?, overlay: KeyBinding?, layer: Int) -> Action? {
        if layer != 0 { return binding?.layers?["\(layer)"] ?? binding?.tap }
        if key == .ok { return overlay?.tap ?? .keyStroke(key: "return", mods: []) }
        if key == .back { return .keyStroke(key: "delete", mods: []) }
        if let arrow = arrows[key] { return .keyStroke(key: arrow, mods: []) }
        return binding?.tap
    }

    static func double(key: RemoteKey, action: Action?, layer: Int) -> Action? {
        guard action != Action.none else { return nil }
        guard layer == 0 else { return action }
        if arrows[key] != nil || key == .back { return nil }
        if key == .ok { if case .layerToggle = action { return action }; return nil }
        return action
    }

    static func effective(_ config: MappingConfig, profile: String, key: RemoteKey) -> KeyBinding {
        var result = merged(config, profile: profile, key: key) ?? KeyBinding()
        let overlay = profile == "global" ? nil : config.profiles[profile]?[key.rawValue]
        result.tap = tap(key: key, binding: result, overlay: overlay, layer: 0)
        result.double = double(key: key, action: result.double, layer: 0)
        if config.settings.doubleMs <= 0 { result.double = nil }
        if arrows[key] != nil { result.hold = result.tap }
        if key == .back {
            result.hold = config.settings.deleteAllOnHold == true
                ? .macro(steps: [.action(.keyStroke(key: "a", mods: ["left_cmd"])),
                                 .action(.keyStroke(key: "delete", mods: []))])
                : .keyStroke(key: "delete", mods: [])
        }
        return result
    }

    static func protection(key: RemoteKey, profile: String, slot: String) -> String? {
        if arrows[key] != nil { return "基础态保留光标移动；请在下方配置第二功能模式。" }
        if key == .back { return "基础态保留删除；长按行为由通用页的删除开关决定。" }
        if key == .ok, slot == "tap", profile == "global" { return "全局确认键固定为回车；可在 App 场景中自定义发送键。" }
        if key == .ok, slot == "double" { return "基础态双击仅支持开关功能模式，避免延迟确认操作。" }
        return nil
    }
}
