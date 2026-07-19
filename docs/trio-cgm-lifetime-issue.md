# [Trio] Wire the xDrip app-group sensor expiry into the existing arc + countdown

> Paste into a new issue on `Sjoerd-Bo3/Trio` (branch `Build-Experiment`).
> This is **not** a new-UI request — the arc view, the countdown tag, and the
> formatter already exist and already work for native CGM managers. The only gap
> is that the sensor **expiry date is never derived for the xDrip app-group
> source**, so those existing views stay hidden. One small wiring change fixes it.
> The xDrip half is already shipped (`master` + `update/master-6.3.3` of
> `Sjoerd-Bo3/xdripswift`): the payload now includes `cgm.sensor.expiresAt`.

## Root cause (traced in this fork)

`HomeStateModel.resolveSensorExpiresAt(manager:glucoseSource:lifecycle:)` sources the
sensor expiry **only** from a native `CGMManagerUI` (or the simulator):

```swift
private static func resolveSensorExpiresAt(
    manager: CGMManagerUI?,
    glucoseSource: GlucoseSource?,
    lifecycle: DeviceLifecycleProgress?
) -> Date? {
    // ... simulator special-case ...
    guard let manager else { return nil }   // <-- xDrip app-group source has no manager
    // ...native activatedAt / expiry math...
}
```

The xDrip source is an `AppGroupSource` whose `cgmManager` is `nil`, so this returns
`nil`. Downstream effects in `CurrentGlucoseView`:

- `shouldShowArc` → with `cgmSensorExpiresAt == nil` it falls back to
  `cgmProgress?.progressState != .normalCGM`, so a healthy mid-life sensor
  (`.normalCGM`) shows **no arc**.
- The remaining-time tag (`SensorStatusTagView` + `SensorRemainingTimeFormatter`)
  is driven by `cgmSensorExpiresAt` / `cgmWarmupEndsAt`, both `nil` → **no countdown**.

`AppGroupSource.applyRichState()` already decodes `cgm.sensor` into
`cgmProgressHighlight` (`percentComplete` + `progressState`) — it just throws away
any expiry because the contract had none. xDrip now sends one.

## xDrip side — DONE

`cgm.sensor` now carries an absolute expiry (commit already on `master` +
`update/master-6.3.3`):

| key | type | notes |
| --- | --- | --- |
| `percentComplete` | Double `0...1` | existing |
| `isInWarmup` | Bool | existing |
| `isExpired` | Bool | existing |
| `progressState` | String `"normal"｜"warning"｜"critical"` | existing |
| `expiresAt` | Double | **new** — epoch seconds (`sessionStart + maxAge`) |

Additive key; the current parser ignores it, so nothing breaks before the Trio change lands.

## Trio side — minimal wiring (no new views)

Have the app-group path supply the expiry so the existing views light up. Two small options — pick one:

### Option 1 (smallest): parse `expiresAt` in `AppGroupSource.parseSensorLifecycle`, expose it, use it as a fallback in `resolveSensorExpiresAt`

1. In `AppGroupSource.applyRichState()` / `parseSensorLifecycle(_:)`, read the epoch:

```swift
if let expires = sensor["expiresAt"] as? NSNumber {
    cgmSensorExpiresAtFromPayload.value = Date(timeIntervalSince1970: expires.doubleValue)
} else {
    cgmSensorExpiresAtFromPayload.value = nil
}
```
   (add `let cgmSensorExpiresAtFromPayload = CurrentValueSubject<Date?, Never>(nil)` next to `cgmProgressHighlight`, and observe it in `HomeStateModel` the same way `cgmProgressHighlight` is observed.)

2. In `resolveSensorExpiresAt`, before the `guard let manager`, use the payload value when there is no manager:

```swift
if manager == nil,
   let payloadExpiry = (glucoseSource as? AppGroupSource)?.cgmSensorExpiresAtFromPayload.value {
    return payloadExpiry
}
guard let manager else { return nil }
```

That's it — `cgmSensorExpiresAt` becomes non-nil for xDrip, so `shouldShowArc` enters
its 48h branch near expiry, and the countdown tag renders. No view code changes.

### Option 2 (also show the arc across the *whole* life, not just final 48h)

If you want the ring visible mid-life too (not only within 48h of expiry), also relax
`shouldShowArc` in `CurrentGlucoseView` so having progress data is enough:

```swift
private var shouldShowArc: Bool {
    if isInWarmup { return true }
    if cgmProgress != nil { return true }          // xDrip always sends percentComplete
    if let expiresAt = cgmSensorExpiresAt {
        return expiresAt.timeIntervalSinceNow <= 48 * 60 * 60
    }
    return cgmProgress?.progressState != .normalCGM
}
```

## Acceptance

- Mid-life G6/Anubis via xDrip: lifecycle arc visible; remaining-time tag below the
  glucose bubble shows a live countdown (e.g. `6d 4h`).
- Warm-up and expired states keep their existing messages/icons.
- Native CGM managers are unaffected (payload path only used when `manager == nil`).

## References

- xDrip: `xDrip/Managers/Loop/LoopManager.swift` → `buildTrioCgmStatusDict()` (`expiresAt`).
- Trio (this fork): `Trio/Sources/APS/CGM/AppGroupSource.swift` (`applyRichState`/`parseSensorLifecycle`),
  `Trio/Sources/Modules/Home/HomeStateModel.swift` (`resolveSensorExpiresAt`),
  `Trio/Sources/Modules/Home/View/Header/CurrentGlucoseView.swift` (`shouldShowArc`, `SensorStatusTagView`).
