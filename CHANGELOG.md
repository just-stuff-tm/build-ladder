# Build Ladder Changelog

## v2.2.1 — Termux Stability & Updater Fixes

### Fixed
- Fixed updater to always refresh all runtime scripts
- Prevented stale or missing ~/.build-ladder/bin installs
- Corrected command routing so `doctor` does not enter Forge
- Resolved aapt2 crashes on Termux by enforcing native aapt2
- Fixed Gradle + Android SDK environment detection
- Eliminated partial update failures

### Added
- `build-ladder doctor` command for environment diagnostics
- Termux-specific hardening for Android builds
- Safer bootstrap and updater flow
- Clear donation messaging (`$yuptm`, voluntary)

### Status
- Alpha (Termux tested)
- Android APK builds verified end-to-end
