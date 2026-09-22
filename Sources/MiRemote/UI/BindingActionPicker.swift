import SwiftUI

/// 区分配置槽位、继承来源和受保护的基础态，不把空槽位误报为禁用。
struct BindingActionPicker: View {
    @EnvironmentObject var model: AppModel
    let key: RemoteKey
    let slot: String
    var action: Action?
    var onChange: (Action?) -> Void

    private func value(_ binding: KeyBinding?) -> Action? {
        switch slot {
        case "tap": return binding?.tap
        case "hold": return binding?.hold
        case "double": return binding?.double
        default:
            if slot.hasPrefix("gesture:") { return binding?.gesture?[String(slot.dropFirst(8))] }
            return binding?.layers?[slot]
        }
    }

    private var emptyTitle: String {
        if model.currentProfile != "global" {
            let binding = ["tap", "hold", "double"].contains(slot)
                ? BindingResolver.effective(model.config, profile: "global", key: key)
                : model.config.profiles["global"]?[key.rawValue]
            let inherited = value(binding)
            return "继承全局 · " + (inherited == Action.none ? "不执行" : ActionSummary.describe(inherited))
        }
        return Int(slot) == nil ? "未设置" : "沿用短按动作"
    }

    var body: some View {
        let protection = BindingResolver.protection(key: key, profile: model.currentProfile, slot: slot)
        let baseSlot = ["tap", "hold", "double"].contains(slot)
        if baseSlot, let protection, !(key == .ok && slot == "double") {
            Text(ActionSummary.describe(value(BindingResolver.effective(model.config, profile: model.currentProfile, key: key))))
                .font(.callout).foregroundStyle(.secondary).help(protection)
        } else if key == .ok && slot == "double" {
            Menu {
                Button(emptyTitle) { onChange(nil) }
                Button("不执行") { onChange(Action.none) }
                ForEach(1...3, id: \.self) { layer in
                    Button("开关\(modeDisplayName(layer))") { onChange(.layerToggle(layer)) }
                }
            } label: {
                let effective = BindingResolver.effective(model.config, profile: model.currentProfile, key: key).double
                Text(action == nil ? emptyTitle : (effective == nil ? "不执行" : ActionSummary.describe(effective)))
            }
            .help(protection ?? "")
        } else {
            ActionPicker(action: action, emptyTitle: emptyTitle, onChange: onChange)
        }
    }
}
