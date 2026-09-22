import Foundation

enum UsageActionKind: String, Codable, CaseIterable {
    case keyStroke, system, openApp, shell, voice, layer, window, tab
    case focus, mouse, macro, overlay, other

    init(action: Action) {
        switch action {
        case .keyStroke: self = .keyStroke
        case .system: self = .system
        case .openApp: self = .openApp
        case .shell: self = .shell
        case .voice: self = .voice
        case .layerMomentary, .layerToggle: self = .layer
        case .windowCycle: self = .window
        case .tabJump: self = .tab
        case .focusInput: self = .focus
        case .mouseMode: self = .mouse
        case .macro: self = .macro
        case .overlay: self = .overlay
        case .none: self = .other
        }
    }
}

struct UsageDay: Codable, Equatable, Identifiable {
    var date: String
    var actionTriggers: Int = 0
    var actionsByKey: [String: Int] = [:]
    var actionsByKind: [String: Int] = [:]
    var voiceSessions: Int = 0
    var voiceSampleCount: Int64 = 0
    var testToneCount: Int = 0

    var id: String { date }
    var voiceSeconds: Double { Double(voiceSampleCount) / 16_000.0 }
}

struct UsageSnapshot: Equatable {
    var today: UsageDay
    var recentDays: [UsageDay]
    var last7ActionTriggers: Int
    var last7VoiceSessions: Int
    var last7VoiceSeconds: Double

    static let empty = UsageSnapshot(
        today: UsageDay(date: ""), recentDays: [],
        last7ActionTriggers: 0, last7VoiceSessions: 0, last7VoiceSeconds: 0)
}

private struct UsageDocument: Codable {
    var version = 1
    var days: [String: UsageDay] = [:]
}

/// 仅保存按日聚合数据。所有可变状态都在 queue 上访问；写盘失败不得影响遥控功能。
final class UsageStatisticsStore: @unchecked Sendable {
    static let retentionDays = 90

    private let fileURL: URL
    private let calendar: Calendar
    private let queue = DispatchQueue(label: "com.miremote.usage-statistics")
    private var document: UsageDocument
    private var enabled: Bool
    private var persistenceBlocked = false
    private var pendingSave: DispatchWorkItem?
    private var countedVoiceSessions: Set<UInt64> = []
    private var _onChange: (() -> Void)?

    var onChange: (() -> Void)? {
        get { queue.sync { _onChange } }
        set { queue.sync { _onChange = newValue } }
    }

    static func defaultURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiRemote")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage-stats.json")
    }

    init(fileURL: URL = UsageStatisticsStore.defaultURL(),
         enabled: Bool = true,
         calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.enabled = enabled
        self.calendar = calendar
        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode(UsageDocument.self, from: data), decoded.version == 1 {
                self.document = decoded
            } else {
                self.document = UsageDocument()
                self.persistenceBlocked = true
                log("使用统计文件解析失败，保留原文件并暂不覆盖: \(fileURL.path)")
            }
        } else {
            self.document = UsageDocument()
        }
    }

    func setEnabled(_ value: Bool) {
        queue.async { [self] in enabled = value }
    }

    func recordAction(key: RemoteKey, action: Action, at date: Date = Date()) {
        guard action != .none else { return }
        queue.async { [self] in
            guard enabled else { return }
            mutateDay(at: date) { day in
                day.actionTriggers += 1
                day.actionsByKey[key.rawValue, default: 0] += 1
                day.actionsByKind[UsageActionKind(action: action).rawValue, default: 0] += 1
            }
        }
    }

    /// 首个非空 PCM 批次同时登记会话；同一 sessionID 后续只累加样本。
    func recordVoiceSamples(_ count: Int, sessionID: UInt64, at date: Date = Date()) {
        guard count > 0 else { return }
        queue.async { [self] in
            guard enabled else { return }
            let isFirst = countedVoiceSessions.insert(sessionID).inserted
            mutateDay(at: date, notify: isFirst) { day in
                if isFirst { day.voiceSessions += 1 }
                day.voiceSampleCount += Int64(count)
            }
        }
    }

    func endVoiceSession(_ sessionID: UInt64) {
        queue.async { [self] in
            if countedVoiceSessions.remove(sessionID) != nil { _onChange?() }
        }
    }

    func recordTestTone(at date: Date = Date()) {
        queue.async { [self] in
            guard enabled else { return }
            mutateDay(at: date) { $0.testToneCount += 1 }
        }
    }

    func snapshot(now: Date = Date()) -> UsageSnapshot {
        queue.sync { snapshotLocked(now: now) }
    }

    func clear() {
        queue.sync {
            pendingSave?.cancel()
            pendingSave = nil
            document = UsageDocument()
            countedVoiceSessions.removeAll()
            persistenceBlocked = false
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch {
                log("清空使用统计失败: \(error)")
            }
            _onChange?()
        }
    }

    /// 排空先前异步事件并同步写盘，供退出与测试使用。
    func flush() {
        queue.sync {
            pendingSave?.cancel()
            pendingSave = nil
            saveLocked()
        }
    }

    private func mutateDay(at date: Date, notify: Bool = true,
                           _ body: (inout UsageDay) -> Void) {
        let key = dateKey(date)
        var day = document.days[key] ?? UsageDay(date: key)
        body(&day)
        document.days[key] = day
        trimLocked()
        scheduleSaveLocked()
        if notify { _onChange?() }
    }

    private func scheduleSaveLocked() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveLocked() }
        pendingSave = work
        queue.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func saveLocked() {
        guard !persistenceBlocked else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(document).write(to: fileURL, options: .atomic)
        } catch {
            log("使用统计写入失败: \(error)")
        }
    }

    private func trimLocked() {
        let keep = Set(document.days.keys.sorted().suffix(Self.retentionDays))
        document.days = document.days.filter { keep.contains($0.key) }
    }

    private func snapshotLocked(now: Date) -> UsageSnapshot {
        let todayKey = dateKey(now)
        let today = document.days[todayKey] ?? UsageDay(date: todayKey)
        var recent: [UsageDay] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let key = dateKey(date)
            recent.append(document.days[key] ?? UsageDay(date: key))
        }
        return UsageSnapshot(
            today: today,
            recentDays: recent,
            last7ActionTriggers: recent.reduce(0) { $0 + $1.actionTriggers },
            last7VoiceSessions: recent.reduce(0) { $0 + $1.voiceSessions },
            last7VoiceSeconds: recent.reduce(0) { $0 + $1.voiceSeconds })
    }

    private func dateKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private var storedDayCount: Int { queue.sync { document.days.count } }

    static func selfCheck() -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("miremote-usage-\(UUID().uuidString)")
        let url = dir.appendingPathComponent("usage-stats.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = UsageStatisticsStore(fileURL: url, calendar: cal)
        store.recordAction(key: .home, action: .system("mission_control"), at: base)
        store.recordAction(key: .home, action: .none, at: base)
        store.recordVoiceSamples(0, sessionID: 2, at: base)
        store.recordVoiceSamples(8_000, sessionID: 1, at: base)
        store.recordVoiceSamples(8_000, sessionID: 1, at: base)
        store.recordTestTone(at: base)
        store.flush()
        let first = store.snapshot(now: base).today
        guard first.actionTriggers == 1,
              first.actionsByKey["home"] == 1,
              first.voiceSessions == 1,
              first.voiceSampleCount == 16_000,
              first.testToneCount == 1 else { return false }

        store.setEnabled(false)
        store.recordAction(key: .tv, action: .layerToggle(2), at: base)
        store.flush()
        guard store.snapshot(now: base).today.actionTriggers == 1 else { return false }
        store.setEnabled(true)
        for offset in 1...95 {
            let date = cal.date(byAdding: .day, value: offset, to: base)!
            store.recordAction(key: .ok, action: .keyStroke(key: "return", mods: []), at: date)
        }
        store.flush()
        guard store.storedDayCount == retentionDays else { return false }

        let reloaded = UsageStatisticsStore(fileURL: url, calendar: cal)
        let lastDate = cal.date(byAdding: .day, value: 95, to: base)!
        guard reloaded.snapshot(now: lastDate).today.actionTriggers == 1 else { return false }
        reloaded.clear()
        guard reloaded.snapshot(now: lastDate).today.actionTriggers == 0,
              !FileManager.default.fileExists(atPath: url.path) else { return false }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let corrupt = Data("not-json".utf8)
        try? corrupt.write(to: url)
        let blocked = UsageStatisticsStore(fileURL: url, calendar: cal)
        blocked.recordTestTone(at: base)
        blocked.flush()
        guard (try? Data(contentsOf: url)) == corrupt else { return false }
        blocked.clear()
        blocked.recordTestTone(at: base)
        blocked.flush()
        return UsageStatisticsStore(fileURL: url, calendar: cal)
            .snapshot(now: base).today.testToneCount == 1
    }
}
