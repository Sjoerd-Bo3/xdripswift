/// suspension prevention
enum ConstantsSuspensionPrevention {
    
    /// name of the file that has the sound to play
    static let soundFileName = "1-millisecond-of-silence.caf"//20ms-of-silence.caf"
    
    /// how often to play the sound, in seconds, for the normal keep-alive mode
    static let intervalNormal = 5
    
    /// how often to play the sound, in seconds, for the aggressive keep-alive mode
    static let intervalAggressive = 2

    /// how often to play the sound, in seconds, for the master mode keep-alive
    ///
    /// deliberately much longer than the follower intervals. Apple does not document how long an app may stay silent before the system
    /// interrupts the audio session and suspends it, so this is calibrated by observation rather than by the book. Every play is a CPU
    /// wake-up, so at 5 seconds the app is woken over 17.000 times a day - going to 30 cuts that by a factor of six.
    static let intervalMaster = 30

    /// fallback interval, in seconds, used when the master mode keep-alive detects that the app got suspended anyway
    static let intervalMasterFallback = 5

    /// if the master mode keep-alive timer fires this many times later than scheduled, the app was suspended in between and the interval
    /// is too long for this device or iOS version
    static let masterSuspensionDetectionFactor = 3.0
}


