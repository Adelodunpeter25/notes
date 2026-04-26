import Foundation

/// Persists the sync cursor and device ID to UserDefaults.
final class SyncStateStore {
    static let shared = SyncStateStore()

    private let defaults = UserDefaults.standard
    private let cursorKey = "sync_cursor"
    private let deviceIdKey = "sync_device_id"

    var cursor: String? {
        get { defaults.string(forKey: cursorKey) }
        set { defaults.set(newValue, forKey: cursorKey) }
    }

    var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdKey) { return existing }
        let new = UUID().uuidString
        defaults.set(new, forKey: deviceIdKey)
        return new
    }

    func clearCursor() {
        defaults.removeObject(forKey: cursorKey)
    }
}
