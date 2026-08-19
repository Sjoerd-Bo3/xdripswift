/// suspension prevention
enum ConstantsSuspensionPrevention {
    
    /// name of the file that has the sound to play
    static let soundFileName = "1-millisecond-of-silence.caf"//20ms-of-silence.caf"
    
    /// how often to play the sound, in seconds, for the normal keep-alive mode
    static let intervalNormal = 5
    
    /// how often to play the sound, in seconds, for the aggressive keep-alive mode
    static let intervalAggressive = 2

    /// fallback interval, in seconds, used when the master mode keep-alive detects that the app got suspended anyway
    static let intervalMasterFallback = 5

    /// if the master mode keep-alive timer fires this many times later than scheduled, the app was suspended in between and the interval
    /// is too long for this device or iOS version
    static let masterSuspensionDetectionFactor = 3.0
}

/// how often the master mode keep-alive plays its millisecond of silence, or whether it runs at all
///
/// this is a user setting rather than a constant on purpose. Apple does not document how long an app may stay silent under the 'audio'
/// background mode before the system interrupts the session and suspends it anyway - DTS has declined to name a threshold - so the longest
/// interval that still works has to be found by trying it. Every play is a CPU wake-up, so a longer interval is directly less battery :
/// 5 seconds is roughly 17.000 wake-ups a day, 60 seconds is about 1.400.
public enum MasterBackgroundKeepAliveType: Int, CaseIterable {

    // when adding cases, add them at the end, the rawValue is what gets stored in UserDefaults

    case disabled = 0
    case seconds5 = 1
    case seconds15 = 2
    case seconds30 = 3
    case seconds60 = 4
    case seconds120 = 5

    /// interval in seconds, nil if the keep-alive should not run
    var seconds: Int? {
        switch self {
        case .disabled: return nil
        case .seconds5: return 5
        case .seconds15: return 15
        case .seconds30: return 30
        case .seconds60: return 60
        case .seconds120: return 120
        }
    }

    var description: String {
        switch self {
        case .disabled:
            return Texts_SettingsView.masterKeepAliveDisabled
        case .seconds5, .seconds15, .seconds30, .seconds60, .seconds120:
            return (seconds ?? 0).description + " " + Texts_SettingsView.masterKeepAliveSecondsShort
        }
    }
}


