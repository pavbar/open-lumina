# PRD - Open Lumina

This is a living document. Update it in place as scope, decisions, and progress evolve.

## 1. Project Idea
Open Lumina is a straightforward native macOS viewer for X-ray studies distributed as disc images or normal local folders. It exists to reduce friction when opening archived study media and to provide a clean UI for browsing the contained images without requiring a heavyweight clinical workstation.

## 2. Product Goals
- Open local ISO files and local folders with minimal setup.
- Discover study contents with minimal user friction.
- Provide a clean native UI for browsing X-ray images.
- Keep the architecture compatible with future iOS expansion where it makes sense.

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
- The repository is initialized locally and not connected to GitHub publishing yet.
- The repository currently contains documentation and scaffolding only.
- Application implementation has not started yet.

## 6. Durable Decisions
- Open Lumina is macOS-first for v1.
- The initial UI direction is SwiftUI-first.
- v1 is X-ray-first rather than a general medical imaging platform.
- The first supported user inputs are local ISO files and local folders.
- Future iOS support is desirable, but it is not binding on v1.
