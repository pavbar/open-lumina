# Changelog

## 2026-03-30
- Initialized the local `open-lumina` repository.
- Added initial project documentation: `README.md`, `PRD.md`, `AGENTS.md`, and `INDEX.md`.
- Added file-based operational docs under `docs/`.
- Switched task management guidance from local file-based tracking to Taiga `pb-main-kanban`.
- Added the first native macOS viewer build under `OpenLumina.xcodeproj` and `OpenLumina/`.
- Implemented local folder and ISO study opening with privacy-first temporary ISO mounting and cleanup.
- Added DICOMDIR-first study discovery, loose DICOM fallback scanning, and basic grayscale DICOM image rendering.
- Added synthetic unit tests and UI smoke tests, plus repo-local rules that require tests for behavior-changing work when feasible.
- Added repository hygiene files for local build artifact ignores.
- Added session-only diagnostics with explicit export from app Settings and privacy-safe redaction of path-like values.
- Updated product docs to make functional parity across macOS and iOS a durable requirement.
- Refactored shared image rendering boundaries to use `CGImage` instead of `NSImage` so shared logic stays Apple-platform neutral.
- Added an Apache 2.0 `LICENSE` file and linked it from repo docs.
- Added GitHub Actions workflows for CI validation and downloadable unsigned macOS release packaging.
