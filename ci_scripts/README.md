# Xcode Cloud build setup for xDrip4iOS

This folder contains the [Xcode Cloud](https://developer.apple.com/xcode-cloud/)
custom build scripts. Xcode Cloud automatically detects a `ci_scripts/` folder
next to the Xcode project/workspace and runs the scripts it recognises:

| Script              | When it runs                                  |
| ------------------- | --------------------------------------------- |
| `ci_post_clone.sh`  | after the repo is cloned, before the build    |

`ci_post_clone.sh` generates the gitignored `xDripConfigOverride.xcconfig` at the
repo root from environment variables, so a single repository can produce several
side-by-side installable builds without committing any team id or per-variant
identifier. See the comments at the top of that script for the full variable
list.

## One-time setup in App Store Connect / Xcode

Xcode Cloud itself cannot be enabled from this repository — it has to be turned on
with your Apple account:

1. Open the project in **Xcode** (`xdrip.xcworkspace`).
2. **Product ▸ Xcode Cloud ▸ Create Workflow** (or App Store Connect ▸ your app ▸
   **Xcode Cloud**).
3. Select the **xdrip** scheme, grant access to this repository, and let Xcode
   register the bundle identifiers / sign in with your Apple Developer team.
4. Xcode Cloud uses **cloud-managed signing**, so no Fastlane Match secrets are
   needed (those remain only for the GitHub "browser build").

## Three side-by-side builds: normal + left + right

The app's bundle identifier is `com.$(DEVELOPMENT_TEAM).xdripswift$(suffix)` and
every extension/watch target derives from it, so changing one value produces a
fully distinct, separately-installable app. There are two ways to drive the three
variants — pick one.

### Option A (recommended): auto-populated build branches

A GitHub Action — `.github/workflows/populate_build_branches.yml` — mirrors your
working branch into three branches each time you push, baking the variant config
into a committed `xdrip/xDripOverride.xcconfig`:

| Build branch   | Bundle id                      | App name |
| -------------- | ------------------------------ | -------- |
| `build/normal` | `com.<team>.xdripswift`        | default  |
| `build/left`   | `com.<team>.xdripswift.left`   | xDrip L  |
| `build/right`  | `com.<team>.xdripswift.right`  | xDrip R  |

Set-up (once):
1. The Action reads your Team ID from the existing **`TEAMID`** repo secret (the
   same one the browser build uses) and pushes with **`GH_PAT`** — both are
   already configured if your browser build works.
2. Edit the `on: push: branches:` list in the workflow so it watches your real
   working branch.
3. Create **three Xcode Cloud workflows**, each with **Start Conditions ▸ Branch
   Changes** pointed at `build/normal`, `build/left`, and `build/right`
   respectively. No environment variables needed — the branch carries its config.

Then: push your working branch → the Action refreshes all three `build/*`
branches → Xcode Cloud auto-builds each variant. You can also run it manually via
**Actions ▸ "5. Populate Xcode Cloud build branches" ▸ Run workflow**.

### Option B: one branch, three workflows (Xcode Cloud env vars)

If you'd rather not have extra branches, point all three Xcode Cloud workflows at
the *same* branch and differentiate them with **Environment Variables**
(workflow ▸ *Environment* ▸ *Environment Variables*). `ci_post_clone.sh` turns
these into the build config:

| Workflow | `XDRIP_DEVELOPMENT_TEAM` | `XDRIP_BUNDLE_ID_SUFFIX` | `XDRIP_APP_NAME` | Resulting bundle id                  |
| -------- | ------------------------ | ------------------------ | ---------------- | ------------------------------------ |
| Normal   | `<your team id>`         | *(unset)*                | *(unset)*        | `com.<team>.xdripswift`              |
| Left     | `<your team id>`         | `.left`                  | `xDrip L`        | `com.<team>.xdripswift.left`         |
| Right    | `<your team id>`         | `.right`                 | `xDrip R`        | `com.<team>.xdripswift.right`        |

`XDRIP_DEVELOPMENT_TEAM` is your 10-character Team ID (Apple Developer ▸
Membership). The two options don't conflict: the branch-committed
`xdrip/xDripOverride.xcconfig` is applied first, and `ci_post_clone.sh` only
overrides values when its env vars are actually set.

### App-group note (shared container)

The Loop/Trio app groups are intentionally **left unchanged** across all three
variants:

```
group.com.<team>.loopkit.LoopGroup
group.org.nightscout.<team>.trio.trio-app-group
```

So normal/left/right coexist on the device with their own icons and names but
share **one** data container. Only one variant should actively share to Loop/Trio
at a time, otherwise they overwrite each other's readings. (If you later want each
variant to share independently, the app group strings in the six `*.entitlements`
files would need a matching per-variant suffix and new App Groups registered in
your Apple Developer account.)
