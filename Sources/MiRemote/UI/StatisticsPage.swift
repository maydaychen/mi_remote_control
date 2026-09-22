import SwiftUI

@MainActor
struct StatisticsPage: View {
    @EnvironmentObject var model: AppModel
    @State private var showClearConfirmation = false

    private var today: UsageDay { model.usageSnapshot.today }
    private var maxDailyActions: Int {
        max(1, model.usageSnapshot.recentDays.map(\.actionTriggers).max() ?? 0)
    }

    var body: some View {
        SettingsPageLayout {
            PageHeader(title: "统计",
                       subtitle: "了解遥控器如何融入你的日常工作流。所有数据只保存在这台 Mac。")
        } content: {
            VStack(alignment: .leading, spacing: Spacing.section) {
                SettingsGroup(title: "今日概览") {
                    HStack(spacing: 12) {
                        summaryCard(title: "遥控动作", value: "\(today.actionTriggers)", unit: "次",
                                    icon: "av.remote")
                        summaryCard(title: "语音会话", value: "\(today.voiceSessions)", unit: "次",
                                    icon: "mic")
                        summaryCard(title: "语音时长", value: durationText(today.voiceSeconds), unit: "",
                                    icon: "waveform")
                    }
                    .padding(Spacing.cardPadding)

                    RowDivider()
                    SettingsRow(icon: "waveform.badge.magnifyingglass",
                                title: "测试音",
                                subtitle: "测试音不会计入真实语音会话") {
                        Text("\(today.testToneCount) 次")
                            .font(.body.monospacedDigit())
                    }
                }

                SettingsGroup(title: "近 7 天遥控动作") {
                    if model.usageSnapshot.recentDays.allSatisfy({ $0.actionTriggers == 0 }) {
                        ContentUnavailableView("还没有使用数据",
                                               systemImage: "chart.bar.xaxis",
                                               description: Text("使用遥控器后，这里会按天显示趋势。"))
                            .frame(maxWidth: .infinity, minHeight: 170)
                    } else {
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(model.usageSnapshot.recentDays) { day in
                                VStack(spacing: 6) {
                                    Text("\(day.actionTriggers)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    RoundedRectangle(cornerRadius: Radius.small)
                                        .fill(Color.accentColor.opacity(day.actionTriggers == 0 ? 0.16 : 0.75))
                                        .frame(height: max(4, CGFloat(day.actionTriggers) /
                                                           CGFloat(maxDailyActions) * 104))
                                    Text(shortDate(day.date))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 150, alignment: .bottom)
                        .padding(Spacing.cardPadding)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("近 7 天遥控动作，\(trendAccessibilityText)")
                    }
                }

                SettingsGroup(title: "今日按键分布") {
                    if topKeys.isEmpty {
                        Text("今天还没有触发遥控动作。")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.cardPadding)
                    } else {
                        ForEach(Array(topKeys.enumerated()), id: \.element.name) { index, item in
                            if index > 0 { RowDivider() }
                            SettingsRow(icon: "button.programmable",
                                        title: item.name,
                                        subtitle: nil) {
                                Text("\(item.count) 次")
                                    .font(.body.monospacedDigit())
                            }
                        }
                    }
                }

                SettingsGroup(title: "隐私与数据") {
                    SettingsRow(icon: "lock.shield",
                                title: "记录本地使用统计",
                                subtitle: "只保存按日汇总，不保存录音、文字、App 名称或动作内容") {
                        Toggle("", isOn: $model.usageStatisticsEnabled)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    RowDivider()
                    SettingsRow(icon: "trash",
                                iconColor: .red,
                                title: "清空全部统计",
                                subtitle: "删除后不可恢复，不影响按键配置") {
                        Button("清空…", role: .destructive) { showClearConfirmation = true }
                            .controlSize(.small)
                    }
                }
            }
        }
        .onAppear { model.refreshUsage() }
        .alert("清空全部使用统计？", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { model.clearUsage() }
        } message: {
            Text("本机保存的每日动作、语音时长和测试音统计将被永久删除。")
        }
    }

    private func summaryCard(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title2.bold()).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: Radius.badge))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryAccessibilityLabel(title: title, value: value, unit: unit))
    }

    private var topKeys: [(name: String, count: Int)] {
        let sorted = today.actionsByKey.compactMap { raw, count -> (String, Int)? in
            guard let key = RemoteKey(rawValue: raw) else { return nil }
            return (KeyDisplay.name(key), count)
        }.sorted { $0.1 > $1.1 }
        guard sorted.count > 5 else { return sorted }
        let head = Array(sorted.prefix(5))
        return head + [("其他", sorted.dropFirst(5).reduce(0) { $0 + $1.1 })]
    }

    private var trendAccessibilityText: String {
        model.usageSnapshot.recentDays
            .map { "\($0.date) \($0.actionTriggers) 次" }
            .joined(separator: "，")
    }

    private func summaryAccessibilityLabel(title: String, value: String, unit: String) -> String {
        switch title {
        case "语音会话": return "今日语音 \(value)\(unit)"
        case "语音时长": return "语音时长 \(value)\(unit)"
        default: return "今日\(title) \(value)\(unit)"
        }
    }

    private func shortDate(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3 else { return value }
        return "\(parts[1])/\(parts[2])"
    }

    private func durationText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total) 秒" }
        return "\(total / 60) 分 \(total % 60) 秒"
    }
}
