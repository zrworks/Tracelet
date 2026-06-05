## 3.2.2

- **CHORE**: Sync release versions across all federated packages and update Swift Package Manager configuration.

## 3.2.1

- **CHORE**: Re-release — 3.2.0 was partially published without all fixes.

## 3.2.0

- **CHORE**: Bump dependency to tracelet `3.2.0`.


## 3.1.14

- **CHORE**: Sync release versions across workspace.


## 3.1.10

 - Bump "tracelet_firebase" to `3.1.10`.

## 3.1.9

- **FIX**(android): conditionally apply kotlin-android plugin to support older flutter SDKs while preventing warnings in modern Flutter environments.
- **CHORE**(ci): add strict pre-publish flutter build verification step to `release.yml`.

## 3.1.8

- Fix iOS SPM publishing

## 3.1.7

 - **FIX**(android): apply kotlin-android plugin to fix gradle build errors on newer AGP versions.
 - **FIX**(ios): fix SPM source folder paths in release bundling to ensure SDK compiles properly via CocoaPods.
 - **FIX**(ios): fix duplicate module import errors by adding conditional import checks for TraceletSDK.

## 3.1.4

- **CHORE**: Sync release versions across workspace.

## 3.0.1

- **FIX**(ios): Add missing `FlutterFramework` dependency to SPM plugin configuration to resolve compilation failures and `PlatformException`s.

## 3.0.0

- **CHORE**: bump version to match tracelet 3.0.0 release.
- **FEAT**: upgraded `tracelet` core dependency to `^3.0.0` which includes the new high-performance Rust Engine rewrite for improved battery efficiency and tracking reliability.

## 1.0.1

* chore: optimize package description and metadata.

## 1.0.0

* Initial release of the Tracelet Firebase Adapter.
