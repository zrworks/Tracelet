## 3.1.0

- **CHORE**: Sync release versions across workspace.

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
