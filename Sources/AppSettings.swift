import Foundation

/// iPad-side preferences. They are sent to the PC in the Hello message when a connection starts,
/// and can only be changed from the disconnected screen.
enum AppSettings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: ["touchEnabled": true, "audioEnabled": true, "overlayEnabled": true])
    }

    static var touchEnabled: Bool {
        get { defaults.bool(forKey: "touchEnabled") }
        set { defaults.set(newValue, forKey: "touchEnabled") }
    }
    static var audioEnabled: Bool {
        get { defaults.bool(forKey: "audioEnabled") }
        set { defaults.set(newValue, forKey: "audioEnabled") }
    }
    static var overlayEnabled: Bool {
        get { defaults.bool(forKey: "overlayEnabled") }
        set { defaults.set(newValue, forKey: "overlayEnabled") }
    }

    static var flags: FeatureFlags {
        var f: FeatureFlags = []
        if touchEnabled { f.insert(.touch) }
        if audioEnabled { f.insert(.audio) }
        if overlayEnabled { f.insert(.overlay) }
        return f
    }
}
