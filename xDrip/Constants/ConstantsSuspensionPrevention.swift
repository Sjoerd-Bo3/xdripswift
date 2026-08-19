/// suspension prevention
enum ConstantsSuspensionPrevention {
    
    /// name of the file that has the sound to play
    static let soundFileName = "1-millisecond-of-silence.caf"//20ms-of-silence.caf"
    
    /// how often to play the sound, in seconds, for the normal keep-alive mode
    static let intervalNormal = 5
    
    /// how often to play the sound, in seconds, for the aggressive keep-alive mode
    static let intervalAggressive = 2

    /// default interval, in seconds, for the master mode keep-alive
    static let intervalMasterDefault = 30

    /// smallest and largest interval, in seconds, the user may enter for the master mode keep-alive
    static let intervalMasterMinimum = 1
    static let intervalMasterMaximum = 600

    /// fallback interval, in seconds, used when the master mode keep-alive detects that the app got suspended anyway
    static let intervalMasterFallback = 5

    /// if the master mode keep-alive timer fires this many times later than scheduled, the app was suspended in between and the interval
    /// is too long for this device or iOS version
    static let masterSuspensionDetectionFactor = 3.0
}
