# GitHub Actions sccache Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `sccache` into the GitHub Actions workflows (`release.yml` and `ci.yml`) to dramatically speed up Rust compilation.

**Architecture:** Replace the monolithic `Swatinem/rust-cache@v2` with `mozilla-actions/sccache-action@v0.0.4`. Enable global environment variables `RUSTC_WRAPPER` and `SCCACHE_GHA_ENABLED` so that all subsequent `cargo build` and `cargo ndk` commands automatically cache individual objects to the GitHub Actions backend.

**Tech Stack:** GitHub Actions, sccache, Rust, Bash

---

### Task 1: Update Environment Variables in Workflows

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add sccache environment variables to `release.yml`**

Locate the `env:` block near the top of `.github/workflows/release.yml` and add the variables:
```yaml
env:
  FLUTTER_CHANNEL: stable
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
  RUSTC_WRAPPER: sccache
  SCCACHE_GHA_ENABLED: "true"
```

- [ ] **Step 2: Add sccache environment variables to `ci.yml`**

Locate the `env:` block near the top of `.github/workflows/ci.yml` and add the variables:
```yaml
env:
  FLUTTER_CHANNEL: stable
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
  RUSTC_WRAPPER: sccache
  SCCACHE_GHA_ENABLED: "true"
```

### Task 2: Replace `rust-cache` with `sccache-action` in workflows

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Replace in `release.yml`**

In `.github/workflows/release.yml`, find all 6 occurrences of:
```yaml
      - name: Cache Rust
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: |
            sdk/rust-core
```
And replace them entirely with:
```yaml
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4
```

- [ ] **Step 2: Replace in `ci.yml`**

In `.github/workflows/ci.yml`, find all 6 occurrences of:
```yaml
      - name: Cache Rust
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: |
            sdk/rust-core
```
And replace them entirely with:
```yaml
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4
```

### Task 3: Commit

- [ ] **Step 1: Commit workflow changes**

```bash
git add .github/workflows/release.yml .github/workflows/ci.yml
git commit -m "ci: replace rust-cache with sccache to dramatically speed up rust builds"
```
