# PRD - Open Lumina

This is a living document. Update it in place as scope, decisions, and progress evolve.

## 1. Project Idea
Open Lumina is a straightforward native Apple-platform viewer for X-ray studies distributed as disc images or normal local folders. It exists to reduce friction when opening archived study media and to provide a clean UI for browsing the contained images without requiring a heavyweight clinical workstation.

## 2. Product Goals
- Open local ISO files and local folders with minimal setup.
- Discover study contents with minimal user friction.
- Provide a clean native UI for browsing X-ray images.
- Maintain feature parity across macOS and iOS for all supported user-facing capabilities unless a platform restriction is documented explicitly.

## 3. Non-Goals (Current Scope)
- Direct optical-drive support in v1.
- Advanced radiology workflows such as annotations, measurements, or reporting.
- Broad multi-modality support beyond X-ray.
- PACS, network study retrieval, or cloud sync.
- AI interpretation, diagnosis, or decision support features.

## 4. Project Operations
- Last updated: 2026-03-30
- Task management system: `Taiga / pb-main-kanban`
- Canonical planning document: root `PRD.md`.
- Atomic execution tracking and current task state belong in Taiga, not in this document.
- Repo-local `AGENTS.md` defines the project-specific task-management lookup and filing rules.
- This repo uses Taiga board `pb-main-kanban` for backlog, implementation progress, blockers, handoff notes, and completion evidence.
- Chronological repository change history belongs in root `CHANGELOG.md`.
- This PRD records durable product context and settled decisions, not operational task metadata.

## 5. Current Capabilities
- The repository is published on GitHub.
- The repository contains the first native macOS app implementation and is being shaped for future iOS feature parity.
- The app can open local study folders and local ISO images.
- The app can discover studies via `DICOMDIR` first and fall back to scanning DICOM files when needed.
- The app can render a narrow first-build subset of grayscale DICOM X-ray images.
- Synthetic unit tests cover parsing, rendering, cleanup, and view-model navigation.
- GitHub Actions can run CI builds and package unsigned macOS release artifacts.

## 6. Durable Decisions
- Open Lumina is shipping on macOS first, but every new feature must be designed for eventual iOS parity.
- The initial UI direction is SwiftUI-first.
- v1 is X-ray-first rather than a general medical imaging platform.
- The first supported user inputs are local ISO files and local folders.
- Shared domain, parsing, rendering, and state logic should stay platform-neutral wherever possible; platform-specific code belongs at file access, app shell, and presentation boundaries.
- Exact UI parity is not required, but functional parity is the default expectation across macOS and iOS.
- Any feature that cannot reach parity because of platform restrictions must document the exception explicitly in this PRD.
- The repository should remain public-GitHub safe from day one.
- CI should produce downloadable macOS build artifacts for public testing, while keeping signing credentials out of the repository.
- The product should stay compatible with future Mac App Store distribution.
- Unsigned GitHub release artifacts are acceptable for early OSS distribution, but Developer ID signing and notarization are required for a frictionless public install flow.
- Default privacy posture is local-only and session-scoped. Opened studies, extracted ISO contents, and identifying metadata are not stored durably by default.
- v1 should prefer Apple frameworks and avoid third-party telemetry, cloud dependencies, and secret-bearing configuration.
- The first study-discovery contract is `DICOMDIR` first with loose DICOM fallback.
