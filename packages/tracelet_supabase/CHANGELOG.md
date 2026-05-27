## 3.1.0

**FEAT**: Major architectural upgrade: Unified Rust Core.
- The heavy lifting for Geofences, Privacy Zones, Audit Trail, and SQLite persistence has been moved to a shared Rust core (`tracelet_core`).
- Guarantees 100% mathematical and behavioral parity between iOS and Android.
- Eliminates subtle cross-platform inconsistencies in geofence ray-casting and proximity evaluation.
- Native SDK wrappers (Swift/Kotlin) have been thinned out to act purely as FFI bridges via UniFFI.

**FEAT**: Introduced explicit predefined tracking profiles: `Config.highAccuracy()`, `Config.balanced()`, and `Config.lowPower()` to simplify setup.

**CHORE**: Release strategy overhaul. The iOS Rust Core is now bundled directly into the `tracelet_ios` plugin for pub.dev publication, while the Android SDK continues to be distributed via Maven Central.

## 3.0.1

- **FIX**(ios): Add missing `FlutterFramework` dependency to SPM plugin configuration to resolve compilation failures and `PlatformException`s.

## 3.0.0

- **CHORE**: bump version to match tracelet 3.0.0 release.
- **FEAT**: upgraded `tracelet` core dependency to `^3.0.0` which includes the new high-performance Rust Engine rewrite for improved battery efficiency and tracking reliability.

## 1.0.2

* chore: optimize package description and metadata.

## 1.0.0

* Initial release of the Tracelet Supabase Adapter.
* Added `TraceletSupabase.buildHttpConfig()` for zero-config native background syncing to Supabase.
* Added `TraceletSupabase.configureTokenRefresh()` for automatic foreground and headless JWT token recovery.
