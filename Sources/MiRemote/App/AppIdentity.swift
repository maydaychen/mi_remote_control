import Foundation

/// 对外品牌与 bundle 身份集中在这里；Swift 模块和历史数据目录继续保留内部名称 MiRemote。
enum AppIdentity {
    static let englishName = "RemoKey"
    static let chineseName = "遥键"
    static let bundleIdentifier = "com.remokey.controller"
    static let legacyBundleIdentifier = "com.miremote.controller"

    private static let preferencesMigrationKey = "RemoKey.didMigrateMiRemotePreferences"

    /// Bundle ID 改名会切换 UserDefaults domain。首次启动新身份时复制旧偏好，
    /// 新 domain 已有的值优先，避免覆盖用户在 RemoKey 中做出的新设置。
    static func migrateLegacyPreferencesIfNeeded(
        defaults: UserDefaults = .standard,
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        legacyDomain: String = legacyBundleIdentifier,
        targetDomain: String = bundleIdentifier
    ) {
        guard currentBundleIdentifier == targetDomain,
              !defaults.bool(forKey: preferencesMigrationKey)
        else { return }

        let legacy = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        let current = defaults.persistentDomain(forName: targetDomain) ?? [:]
        if !legacy.isEmpty {
            let merged = legacy.merging(current) { _, newValue in newValue }
            defaults.setPersistentDomain(merged, forName: targetDomain)
        }
        defaults.set(true, forKey: preferencesMigrationKey)
    }
}
