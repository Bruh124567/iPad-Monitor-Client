import Foundation

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
        var flags: FeatureFlags = []
        if touchEnabled { flags.insert(.touch) }
        if audioEnabled { flags.insert(.audio) }
        if overlayEnabled { flags.insert(.overlay) }
        return flags
    }

    static func apply(flags: FeatureFlags) {
        touchEnabled = flags.contains(.touch)
        audioEnabled = flags.contains(.audio)
        overlayEnabled = flags.contains(.overlay)
    }
}
