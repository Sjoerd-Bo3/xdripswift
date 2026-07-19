# Agent prompt — wire xDrip app-group sensor expiry into Trio's existing arc + countdown

> Paste the block below to an agent working in **Sjoerd-Bo3/Trio**, branch **`Build-Experiment`**.

---

You are working in the **Sjoerd-Bo3/Trio** repository on branch **`Build-Experiment`**. Make a small wiring change so the sensor **lifecycle arc** and the **remaining-time countdown** (both already implemented in the UI) also work when the CGM source is **xDrip via the shared app group**, not just for native CGM managers.

**Root cause (already diagnosed — do not re-litigate):**
`HomeStateModel.resolveSensorExpiresAt(manager:glucoseSource:lifecycle:)` sources the sensor expiry only from a native `CGMManagerUI` (or the simulator) — it has `guard let manager else { return nil }`. The xDrip source is an `AppGroupSource` whose `cgmManager` is `nil`, so `cgmSensorExpiresAt` stays `nil`. As a result, in `CurrentGlucoseView`: the countdown tag (`SensorStatusTagView` / `SensorRemainingTimeFormatter`) never renders, and `shouldShowArc` falls back to `progressState != .normalCGM`, hiding the arc for a healthy mid-life sensor.

**Upstream is ready:** xDrip already sends `cgm.sensor.expiresAt` (a `Double`, epoch seconds) in the shared app-group payload. `AppGroupSource.applyRichState()` already decodes `cgm.sensor` (`percentComplete`, `progressState`, `isInWarmup`, `isExpired`) into `cgmProgressHighlight`; it just discards any expiry.

**Do this:**

1. In `Trio/Sources/APS/CGM/AppGroupSource.swift`: add a publisher next to `cgmProgressHighlight`:
   ```swift
   let cgmSensorExpiresAtFromPayload = CurrentValueSubject<Date?, Never>(nil)
   ```
   In `applyRichState(_:)` (where `cgm.sensor` is parsed), set it:
   ```swift
   if let expires = (cgm?["sensor"] as? [String: Any])?["expiresAt"] as? NSNumber {
       cgmSensorExpiresAtFromPayload.value = Date(timeIntervalSince1970: expires.doubleValue)
   } else {
       cgmSensorExpiresAtFromPayload.value = nil
   }
   ```

2. In `Trio/Sources/Modules/Home/HomeStateModel.swift`, function `resolveSensorExpiresAt(manager:glucoseSource:lifecycle:)`: before `guard let manager`, add a fallback for the app-group source:
   ```swift
   if manager == nil,
      let payloadExpiry = (glucoseSource as? AppGroupSource)?.cgmSensorExpiresAtFromPayload.value {
       return payloadExpiry
   }
   ```

3. **Optional** — to show the arc across the *whole* sensor life (not only within 48h of expiry), in `Trio/Sources/Modules/Home/View/Header/CurrentGlucoseView.swift`, update `shouldShowArc`:
   ```swift
   private var shouldShowArc: Bool {
       if isInWarmup { return true }
       if cgmProgress != nil { return true }   // xDrip always sends percentComplete
       if let expiresAt = cgmSensorExpiresAt {
           return expiresAt.timeIntervalSinceNow <= 48 * 60 * 60
       }
       return cgmProgress?.progressState != .normalCGM
   }
   ```

**Constraints:** Reuse existing views/formatters — do not create new UI. Native CGM managers and the simulator must be unaffected (the payload fallback only applies when `manager == nil`). Build must compile.

**Acceptance:** With xDrip as the CGM source and a mid-life sensor, the lifecycle arc is visible and a live remaining-time countdown (e.g. `6d 4h`) appears below the glucose bubble; warm-up and expired states keep their existing behavior.
