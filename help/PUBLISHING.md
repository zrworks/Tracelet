# Publishing Guide

> Complete reference for releasing Tracelet — native SDKs and Flutter packages.

## Architecture Overview

Tracelet ships **three independent distribution channels**:

| Channel | Artifact | Registry | Current Version |
|---------|----------|----------|-----------------|
| Android SDK | `com.ikolvi:tracelet-sdk` | Maven Central | See `sdk/android/gradle.properties` |
| iOS SDK | `TraceletSDK` | GitHub Release (Bundled in Flutter) | See `TraceletSDK.podspec` |
| Flutter | 7 federated packages | pub.dev | See `packages/tracelet/pubspec.yaml` |

The native SDKs (Android + iOS) version independently from Flutter packages. Flutter packages are always version-locked together (including the `tracelet_doctor` diagnostics package).

---

## Publishing Order

```
┌──────────────────────────────────────────────────────────┐
│  1. Native SDKs (independent, can publish in parallel)   │
│     ├── Android SDK → Maven Central                      │
│     └── iOS SDK     → Pre-compiled & Bundled             │
├──────────────────────────────────────────────────────────┤
│  2. Flutter packages (strict sequential order)           │
│     ├── tracelet_platform_interface  (no Tracelet deps)  │
│     ├── tracelet_android             (depends on ^above) │
│     ├── tracelet_ios                 (depends on ^above) │
│     ├── tracelet_web                 (depends on ^above) │
│     ├── tracelet                     (depends on all)    │
│     ├── tracelet_sync                (depends on tracelet)│
│     └── tracelet_doctor              (depends on tracelet)│
└──────────────────────────────────────────────────────────┘
```

**Why this order matters:**
- pub.dev resolves dependencies at publish time — a package cannot reference a version that doesn't exist yet.
- `tracelet_android`, `tracelet_ios`, and `tracelet_web` all depend on `tracelet_platform_interface`, so interface must be published first.
- The app-facing `tracelet` package depends on all implementations, so it publishes next.
- The diagnostics helper `tracelet_doctor` package depends on `tracelet`, so it must be published last of all.

---

## Pre-Release Checklist

Before triggering a release, update these files manually:

### Flutter packages (all 7 must match)
- [ ] `packages/tracelet/pubspec.yaml` — bump `version:`
- [ ] `packages/tracelet_sync/pubspec.yaml` — bump `version:`
- [ ] `packages/tracelet_platform_interface/pubspec.yaml` — bump `version:`
- [ ] `packages/tracelet_android/pubspec.yaml` — bump `version:` + update `tracelet_platform_interface: ^X.Y.Z`
- [ ] `packages/tracelet_android/android/build.gradle` — update `version = "X.Y.Z"` AND update native SDK reference `implementation("com.ikolvi:tracelet-sdk:X.Y.Z")`
- [ ] `packages/tracelet_ios/pubspec.yaml` — bump `version:` + update `tracelet_platform_interface: ^X.Y.Z`
- [ ] `packages/tracelet_ios/ios/tracelet_ios.podspec` — update `s.version` AND update native SDK reference `s.dependency 'TraceletSDK', 'X.Y.Z'`
- [ ] `packages/tracelet_web/pubspec.yaml` — bump `version:` + update `tracelet_platform_interface: ^X.Y.Z`
- [ ] `packages/tracelet/pubspec.yaml` — update dependencies for `tracelet_android`, `tracelet_ios`, `tracelet_web` to `^X.Y.Z`
- [ ] `packages/tracelet_doctor/pubspec.yaml` — bump `version:` + update `tracelet: ^X.Y.Z`
- [ ] All 6 `CHANGELOG.md` files — add entry with `**FEAT**:` / `**FIX**:` / `**PERF**:` prefix

### Code Quality & Validation
- [ ] Run `dart run melos run format:fix` to auto-format all package code
- [ ] Run `dart run melos run analyze` to ensure zero analysis errors/warnings
- [ ] Run `dart run melos run test` to confirm all package unit tests pass perfectly

### Android SDK (only if native SDK changed)
- [ ] `sdk/android/gradle.properties` — update `SDK_VERSION=X.Y.Z`
- [ ] `sdk/android/CHANGELOG.md`

### iOS SDK (only if native SDK changed)
- [ ] `TraceletSDK.podspec` (repo root) — update `s.version`
- [ ] `sdk/ios/TraceletSDK.podspec` — update `s.version` (keep in sync with root)
- [ ] `sdk/ios/CHANGELOG.md`

### Cross-package dependency constraints
When publishing version X.Y.Z, ensure all `^X.Y.Z` constraints point to the version being published:
```yaml
# tracelet_android/pubspec.yaml
tracelet_platform_interface: ^X.Y.Z  # ← must match

# tracelet/pubspec.yaml
tracelet_android: ^X.Y.Z             # ← must match
tracelet_ios: ^X.Y.Z                 # ← must match
tracelet_web: ^X.Y.Z                 # ← must match
tracelet_platform_interface: ^X.Y.Z  # ← must match

# tracelet_doctor/pubspec.yaml & tracelet_sync/pubspec.yaml
tracelet: ^X.Y.Z                     # ← must match
```

---

## Automated Release (Recommended)

The GitHub Actions workflow at `.github/workflows/release.yml` handles the full pipeline:

```bash
# Trigger from GitHub UI: Actions → Release → Run workflow
# Options:
#   dry_run: true          → Build & lint only, no publish
#   skip_native_sdks: true → Publish only Flutter packages
#   skip_flutter: true     → Publish only native SDKs
```

### Pipeline stages

1. **Validate** — lint, analyze, dry-run checks, extract version numbers
2. **Publish Android SDK** → Maven Central (parallel with iOS)
   - `./gradlew :tracelet-sdk:assembleRelease`
   - `./gradlew :tracelet-sdk:testReleaseUnitTest`
   - `./gradlew publishToSonatype closeAndReleaseSonatypeStagingRepository`
   - Creates git tag: `sdk-android-vX.Y.Z`
3. **Publish iOS SDK** → GitHub Releases (Bundled via pub.dev)
   - `swift build` + `swift test`
   - `./sdk/rust-core/build-ios.sh`
   - Bundled as `TraceletCore.xcframework.zip`
   - Injected into `packages/tracelet_ios/ios/Frameworks/`
   - Creates git tag: `sdk-ios-vX.Y.Z`
4. **Publish Flutter** → pub.dev (sequential, after native SDKs)
   - `dart pub publish --force` for each package in dependency order
   - 30s pause between packages for pub.dev indexing
   - Creates git tags: `tracelet_platform_interface-vX.Y.Z`, etc.

### Required secrets (GitHub repository settings)

| Secret | Purpose | Used by |
|--------|---------|---------|
| `OSSRH_USERNAME` | Maven Central login | Android SDK |
| `OSSRH_PASSWORD` | Maven Central password | Android SDK |
| `SIGNING_KEY` | GPG private key (ASCII-armored) | Android SDK |
| `SIGNING_PASSWORD` | GPG key passphrase | Android SDK |
| `COCOAPODS_TRUNK_TOKEN` | CocoaPods trunk auth | iOS SDK |
| `PUB_CREDENTIALS` | pub.dev OIDC credentials JSON | Flutter |

---

## Manual Release (Per-Channel)

### Android SDK → Maven Central

```bash
cd sdk/android

# 1. Local validation
./gradlew :tracelet-sdk:assembleRelease
./gradlew :tracelet-sdk:testReleaseUnitTest

# 2. Publish to local Maven (smoke test)
./gradlew :tracelet-sdk:publishReleasePublicationToMavenLocal

# 3. Publish to Maven Central
export OSSRH_USERNAME="..."
export OSSRH_PASSWORD="..."
export SIGNING_KEY="$(cat /path/to/private-key.asc)"
export SIGNING_PASSWORD="..."
./gradlew publishToSonatype closeAndReleaseSonatypeStagingRepository

# 4. Tag
git tag sdk-android-vX.Y.Z && git push origin sdk-android-vX.Y.Z
```

**Maven coordinates:** `com.ikolvi:tracelet-sdk:X.Y.Z`

### iOS SDK → GitHub Release (Pre-compiled)

```bash
# 1. Build Rust Core & test
cd sdk/ios
swift build -Xswiftc -suppress-warnings
swift test

# 2. Build iOS SDK
cd ../rust-core
./build-ios.sh

# 3. Zip Framework
cd out
zip -r TraceletCore.xcframework.zip TraceletCore.xcframework

# 4. Tag
git tag sdk-ios-vX.Y.Z && git push origin sdk-ios-vX.Y.Z

# Note: The zip must be uploaded to the GitHub release manually, or use CI.
```

### Flutter → pub.dev

```bash
# Publish in strict order — wait for each to appear on pub.dev before next

# 1. Platform interface (no deps)
cd packages/tracelet_platform_interface
dart pub publish --force

# 2. Platform implementations (wait 30s after step 1)
cd packages/tracelet_android && dart pub publish --force
cd packages/tracelet_ios && dart pub publish --force
cd packages/tracelet_web && dart pub publish --force

# 3. App-facing package (wait 30s after step 2)
cd packages/tracelet && dart pub publish --force

# 4. Sync package (wait 30s after step 3)
cd packages/tracelet_sync && dart pub publish --force

# 5. Diagnostics helper package (wait 30s after step 4)
cd packages/tracelet_doctor && dart pub publish --force

# 6. Tags
git tag tracelet_platform_interface-vX.Y.Z
git tag tracelet_android-vX.Y.Z
git tag tracelet_ios-vX.Y.Z
git tag tracelet_web-vX.Y.Z
git tag tracelet-vX.Y.Z
git tag tracelet_sync-vX.Y.Z
git tag tracelet_doctor-vX.Y.Z
git push origin --tags
```

---

## Version Bumping & Quality Verification with Melos

For Flutter packages, Melos can automate version bumps and changelog generation:

```bash
melos version   # Interactive — bumps all packages, updates CHANGELOGs
```

This updates all 7 Flutter package versions and cross-references in a single commit. Native SDK versions must still be bumped manually.

To verify and automatically apply code formatting across all packages before release:

```bash
# Fix and apply formatting across all packages
dart run melos run format:fix

# Verify that formatting is completely correct
dart run melos run format
```

---

## File Locations Quick Reference

| What | Path |
|------|------|
| Flutter package versions | `packages/*/pubspec.yaml` |
| Flutter native versions | `tracelet_android/android/build.gradle` & `tracelet_ios/ios/*.podspec` |
| Flutter changelogs | `packages/*/CHANGELOG.md` |
| Android SDK version | `sdk/android/gradle.properties` → `SDK_VERSION` |
| Android build config | `sdk/android/tracelet-sdk/build.gradle.kts` |
| Android Maven config | `sdk/android/build.gradle.kts` |
| iOS SDK version | `TraceletSDK.podspec` (root) & `sdk/ios/TraceletSDK.podspec` |
| iOS SPM manifest | `sdk/ios/Package.swift` |
| Release CI workflow | `.github/workflows/release.yml` |
| CI workflow | `.github/workflows/ci.yml` |
| GPG signing keys | `gpg-signing-key-*.asc` (repo root) |

---

## Git Tag Convention

| Component | Tag format | Example |
|-----------|-----------|---------|
| Android SDK | `sdk-android-vX.Y.Z` | `sdk-android-v1.0.1` |
| iOS SDK | `sdk-ios-vX.Y.Z` | `sdk-ios-v1.0.1` |
| Flutter interface | `tracelet_platform_interface-vX.Y.Z` | `tracelet_platform_interface-v1.8.1` |
| Flutter Android | `tracelet_android-vX.Y.Z` | `tracelet_android-v1.8.1` |
| Flutter iOS | `tracelet_ios-vX.Y.Z` | `tracelet_ios-v1.8.1` |
| Flutter Web | `tracelet_web-vX.Y.Z` | `tracelet_web-v1.8.1` |
| Flutter app-facing | `tracelet-vX.Y.Z` | `tracelet-v1.8.1` |
| Flutter sync | `tracelet_sync-vX.Y.Z` | `tracelet_sync-v1.8.1` |
| Flutter doctor | `tracelet_doctor-vX.Y.Z` | `tracelet_doctor-v1.0.1` |

---

## Troubleshooting

**pub.dev dependency resolution fails:**
Ensure the `^X.Y.Z` constraint in dependent packages points to a version that already exists on pub.dev. Publish in order.

**Maven Central staging repo stuck:**
Run `./gradlew closeAndReleaseSonatypeStagingRepository` separately. Check [oss.sonatype.org](https://oss.sonatype.org) for pending staging repos.

**CocoaPods trunk push fails with 409:**
The version already exists. Bump `s.version` in `TraceletSDK.podspec`.

**CocoaPods trunk push timeout:**
The CI workflow retries 3 times with 30s → 60s → 120s backoff. For manual runs, wait and retry.
