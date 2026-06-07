# Design Specification: GitHub Actions `sccache` Integration

## Overview
Currently, the Tracelet SDK's GitHub Actions release workflow (`.github/workflows/release.yml`) uses `Swatinem/rust-cache@v2` for caching the Rust build artifacts. This caches the entire `target/` directory, which can be inefficient and slow due to large cache sizes and frequent cache invalidations. To drastically speed up the CI build process, we will integrate `sccache` (Mozilla's ccache for Rust) to cache individual compilation artifacts.

## Goals
- Significantly reduce the build time for the Android and iOS native Rust Core in the GitHub Actions `release.yml` workflow.
- Replace or augment the monolithic `target/` caching with granular artifact-level caching via `sccache`.
- Keep the local developer build shell scripts (`build-ios.sh`, `build-android.sh`) unmodified so they remain decoupled from the CI-specific caching tool.

## Architecture & Implementation Details

### 1. GitHub Actions sccache setup
We will modify `.github/workflows/release.yml` in jobs that build the Rust core (`validate`, `publish-android-sdk`, `publish-ios-sdk`, `test-flutter-android`, `test-flutter-ios`, `publish-flutter`).
- We will replace `Swatinem/rust-cache@v2` with `mozilla-actions/sccache-action`.
- `sccache-action` integrates natively with GitHub Actions Cache API, allowing the compiled artifacts to be stored directly in GitHub's cache infrastructure.

### 2. Environment Variables Configuration
For `sccache` to work properly in GitHub actions, we need to inject specific environment variables:
- `RUSTC_WRAPPER`: Set to `sccache`. This tells `cargo` to use `sccache` as a wrapper around `rustc`.
- `SCCACHE_GHA_ENABLED`: Set to `"true"` to enable the GitHub Actions native cache backend.
- `ACTIONS_CACHE_URL` and `ACTIONS_RUNTIME_TOKEN`: Automatically injected by GitHub Actions, required by `sccache` to authenticate and upload/download cache.

### 3. Workflow modifications
In each relevant job of `release.yml`:
```yaml
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4
```
And add environment variables directly at the workflow or job level:
```yaml
env:
  RUSTC_WRAPPER: sccache
  SCCACHE_GHA_ENABLED: "true"
```
*(We will verify the latest action version/usage for mozilla-actions/sccache-action during the implementation phase)*

## Trade-offs & Considerations
- **Cache Size Limit:** GitHub Actions has a cache size limit per repository (typically 10GB). Since `sccache` granularly caches objects, it might be more efficient than monolithic caching, but we should monitor cache eviction.
- **First Build Time:** The initial build after introducing `sccache` will take roughly the same time (or slightly longer) as a clean build because it has to populate the cache. Subsequent builds will be significantly faster.

## Verification
- Run a dry-run release workflow dispatch (`dry_run: true`).
- Inspect the Action logs to verify that `sccache` is being invoked during compilation.
- Compare the execution time of the `cargo build` and `cargo ndk` steps between the previous cached run and the new `sccache` run.
