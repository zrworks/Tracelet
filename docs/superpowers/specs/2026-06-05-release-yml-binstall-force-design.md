# Release Workflow `cargo binstall` Force Fix

## Problem
The `release.yml` GitHub Actions workflow fails during the "Generate Rust Bindings" step with `flutter_rust_bridge_codegen: command not found`. This is caused by `cargo binstall` detecting cached metadata from a previous run and skipping the download, even though the actual executable isn't cached in the `$PATH` (`~/.cargo/bin`).

## Solution
Append the `--force` flag to all `cargo binstall` commands inside `.github/workflows/release.yml`. This matches the behavior already established in `ci.yml`.

By forcing the installation, `cargo binstall` will always download the binaries regardless of stale cache metadata, ensuring the executables are reliably available for subsequent steps.

## Components Modified
- `.github/workflows/release.yml`
