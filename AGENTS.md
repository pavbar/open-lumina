# AGENTS.md (repo-scoped)

## Purpose of this repo
- Build Open Lumina as a simple native macOS viewer for X-ray studies stored in local ISO files or folders.
- Keep the repository oriented toward a focused first release instead of expanding prematurely into a full imaging platform.
- Preserve a path to future iOS support without letting that future scope distort v1 decisions.

## Instruction priority (repo-local)
1. The user's explicit instructions in the current chat/session.
2. Repo-local docs (`AGENTS.md`, `README.md`, `PRD.md`, `INDEX.md`, `CHANGELOG.md`, `docs/`).
3. Client/global agent instructions.
4. Tool defaults.

If two instructions conflict, follow the higher priority one and state the conflict briefly.

## Context gathering
- Read `README.md`, `PRD.md`, and `INDEX.md` before changing behavior.
- Treat `INDEX.md` as the canonical structure map and update it in the same change when structure changes.
- Keep `CHANGELOG.md` updated for durable repository history when meaningful changes land.

## Repo map
- Canonical structure map: `INDEX.md`.
- Durable product context: `PRD.md`.
- Repository history: `CHANGELOG.md`.

## Task management
- This repo uses Taiga board `pb-main-kanban` for task tracking.
- Keep durable product context in `PRD.md`; keep atomic execution tracking, blockers, handoff notes, and current task state in Taiga.
- When work needs task creation, status updates, blocker tracking, handoff notes, or completion evidence, use the `task-management` skill and follow the Taiga workflow.
- Track unresolved clarification or investigation items in Taiga rather than in committed repo docs.
- Apply the repository tag `open-lumina` to Taiga issues and user stories so this repo stays filterable inside the shared board.

## Product and implementation direction
- Prefer native Apple-stack work. Do not default to Electron, web-first, or cross-platform shell approaches unless the user explicitly changes direction.
- Keep SwiftUI as the default UI direction unless a concrete constraint requires otherwise.
- Keep v1 focused on opening local ISO files and local folders for X-ray viewing.
- Treat future iOS support as a design constraint for clean boundaries, not as a reason to widen scope prematurely.

## Privacy and sample data
- Treat this as a public-facing OSS repository from day one.
- Never commit real patient data, real medical images, identifying study metadata, or private infrastructure details.
- Use only synthetic, de-identified, or explicitly safe sample data in docs, tests, and fixtures.

## Change policy
- Prefer small, reversible changes.
- Update docs in the same change when scope, architecture, workflows, or repository structure changes.
- Keep rules in the narrowest correct scope.

## Verification
- Run the smallest relevant verification for the change.
- For documentation-only changes, verify structure, links, and declared canonical paths.

## What not to do
- Do not add app implementation code until the project moves beyond the current docs-only stage.
- Do not wire up GitHub remotes, CI, or release automation unless explicitly asked.
