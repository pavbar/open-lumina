# Open Lumina

## Core docs
- [README.md](README.md) - project overview and intended direction
- [PRD.md](PRD.md) - durable product context and decisions
- [CHANGELOG.md](CHANGELOG.md) - chronological repository history
- [AGENTS.md](AGENTS.md) - repo-scoped instructions for agents
- [LICENSE](LICENSE) - Apache License 2.0 terms for the repository
- [Package.swift](Package.swift) - SwiftPM manifest for fast local builds and unit tests
- [.github/workflows](.github/workflows) - GitHub Actions CI and release packaging workflows

## App code
- [OpenLumina](OpenLumina) - native macOS application sources
- [OpenLumina/Resources](OpenLumina/Resources) - app resources, including the asset catalog and deterministic icon source
- [OpenLumina.xcodeproj](OpenLumina.xcodeproj) - native Xcode project with app, unit tests, and UI tests
- [OpenLuminaTests](OpenLuminaTests) - synthetic unit test coverage for parsing, cleanup, rendering, and state
- [OpenLuminaUITests](OpenLuminaUITests) - UI smoke tests for launch and synthetic open flows

## Task tracking
- Taiga `pb-main-kanban` - canonical backlog, active execution state, blockers, handoff notes, and completion evidence
