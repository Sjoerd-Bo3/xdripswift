# [Trio] Always show xDrip sensor arc + render remaining sensor lifetime below the glucose bubble

> Paste this into a new issue on `Sjoerd-Bo3/Trio` (branch `Build-Experiment`).
> The xDrip half is already implemented and shipped to `master` + `update/master-6.3.3`
> of `Sjoerd-Bo3/xdripswift`; the work below is entirely in the Trio app.

## Background

xDrip shares a rich CGM status to Trio via the shared app group. The end-to-end chain works:

- xDrip `LoopManager.buildTrioCgmStatusDict()` writes a `cgm` dict into the shared payload.
- Trio `AppGroupSource.applyRichState()` reads it → publishers (`cgmDisplayState` / `cgmProgressHighlight`) → `HomeStateModel` → `CurrentGlucoseView`.

Two things don't behave as wanted with a mid-life sensor (e.g. a G6 **Anubis** with extended max-age):

1. **The lifecycle arc is hidden mid-life.** `CurrentGlucoseView.shouldShowArc` (Build-Experiment, ~L232) only shows the arc during warm-up, within 48h of expiry, or when `progressState != .normalCGM`. A healthy mid-life sensor is `.normalCGM` and nowhere near expiry, so the arc never renders. By-design gating, not a bug — but we want the arc visible across the whole sensor life.
2. **No remaining-lifetime text below the glucose bubble.** Trio never received an absolute expiry/remaining value, only `percentComplete`, so it had nothing to render as a countdown.

## xDrip side — DONE (no action needed)

`LoopManager.buildTrioCgmStatusDict()` now emits absolute lifetime fields in `cgm.sensor`. Full `cgm.sensor` shape Trio now receives:

| key | type | notes |
| --- | --- | --- |
| `percentComplete` | Double `0...1` | existing |
| `isInWarmup` | Bool | existing |
| `isExpired` | Bool | existing |
| `progressState` | String `"normal"｜"warning"｜"critical"` | existing |
| `sessionStartDate` | Double | **new** — epoch seconds |
| `expiresAt` | Double | **new** — epoch seconds (start + maxAge) |
| `maxSensorAgeInDays` | Double | **new** |
| `remainingMinutes` | Double | **new** — convenience; `≥ 0` |

`cgm.status` (unchanged): `{ localizedMessage: String, displayState: "normal"｜"warning"｜"critical"｜"warmup"｜"expired", imageName: String }`. Keys are additive — the current parser ignores unknown fields, so nothing breaks before the Trio change lands.

## Trio side — TODO

### 1. Parse the new lifetime fields in `AppGroupSource.applyRichState()`

Read `expiresAt` (and optionally `sessionStartDate` / `remainingMinutes`) from the `sensor` dict and populate whatever backs `cgmSensorExpiresAt`. Today nothing sets it, so it's always `nil` and the arc gate falls through to `progressState`.

```swift
// inside applyRichState(), where the sensor sub-dict is decoded:
if let sensor = cgm["sensor"] as? [String: Any] {
    // ...existing percentComplete / isInWarmup / isExpired / progressState...
    if let expires = sensor["expiresAt"] as? Double {
        cgmSensorExpiresAt = Date(timeIntervalSince1970: expires)
    }
    if let start = sensor["sessionStartDate"] as? Double {
        cgmSensorSessionStart = Date(timeIntervalSince1970: start)
    }
    if let remaining = sensor["remainingMinutes"] as? Double {
        cgmSensorRemainingMinutes = remaining
    }
}
```

Publish `cgmSensorExpiresAt` (and remaining) up through the same publisher path the other sensor fields use so `CurrentGlucoseView` can bind to it.

### 2. Show the arc across the whole sensor life — `CurrentGlucoseView.shouldShowArc`

Once `cgmSensorExpiresAt` / `percentComplete` are populated, widen the gate so the arc is shown whenever we have sensor-progress data, not only near expiry:

```swift
private var shouldShowArc: Bool {
    if isInWarmup { return true }
    // Show the arc for the whole sensor life whenever xDrip gave us progress data.
    if cgmProgress?.percentComplete != nil || cgmSensorExpiresAt != nil { return true }
    return cgmProgress?.progressState != .normalCGM
}
```

(If you'd rather keep it conservative, at minimum the arc will now light up within 48h of expiry because `cgmSensorExpiresAt` is finally non-nil.)

### 3. Render remaining lifetime below the glucose bubble

Add a small label under the bubble in `CurrentGlucoseView` driven by `cgmSensorExpiresAt` (fallback `remainingMinutes`). Suggested formatter + view:

```swift
private var sensorLifetimeText: String? {
    guard let expires = cgmSensorExpiresAt else {
        if let m = cgmSensorRemainingMinutes, m > 0 {
            return Self.formatRemaining(minutes: m)
        }
        return nil
    }
    let minutes = expires.timeIntervalSinceNow / 60
    return minutes > 0 ? Self.formatRemaining(minutes: minutes) : "Expired"
}

private static func formatRemaining(minutes: Double) -> String {
    let total = Int(minutes.rounded())
    let d = total / (24 * 60)
    let h = (total % (24 * 60)) / 60
    return d > 0 ? "\(d)d \(h)h" : "\(h)h \(total % 60)m"
}
```

```swift
// under the glucose value in the body:
if let life = sensorLifetimeText {
    Text(life)
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

## Acceptance

- Mid-life G6/Anubis sensor: arc is visible (not hidden by the normal-state gate).
- A remaining-lifetime label (e.g. `6d 4h`) shows below the glucose bubble and counts down.
- Warm-up and expired states still show their existing messages/icons.

## References

- xDrip payload builder: `xDrip/Managers/Loop/LoopManager.swift` → `buildTrioCgmStatusDict()` / `richTrioSharePayload()`
- Trio: `AppGroupSource.applyRichState()`, `CurrentGlucoseView.swift` (`shouldShowArc`, ~L232)
