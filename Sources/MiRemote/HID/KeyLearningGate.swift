import Foundation
import os

/// 识别期间保留 hidutil 过滤，退出后吞掉本次按压的剩余事件，直到物理松开。
final class KeyLearningGate: @unchecked Sendable {
    static let shared = KeyLearningGate()
    private struct State {
        var active = false
        var voiceInProgress = false
        var held: Set<RemoteKey> = []
    }
    private let state = OSAllocatedUnfairLock(initialState: State())
    var isActive: Bool { state.withLock { $0.active } }
    @discardableResult func setActive(_ active: Bool) -> Bool {
        state.withLock {
            guard !active || !$0.voiceInProgress else { return false }
            $0.active = active
            return true
        }
    }
    func beginVoice() -> Bool {
        state.withLock {
            guard !$0.active else { return false }
            $0.voiceInProgress = true
            return true
        }
    }
    func endVoice() { state.withLock { $0.voiceInProgress = false } }
    func captures(_ key: RemoteKey) -> Bool { state.withLock { $0.active || $0.held.contains(key) } }
    func consume(_ event: ButtonEvent) -> Bool {
        state.withLock { value in
            guard value.active || value.held.contains(event.key) else { return false }
            if event.isDown { value.held.insert(event.key) } else { value.held.remove(event.key) }
            return true
        }
    }
}
