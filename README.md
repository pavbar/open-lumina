# Open Lumina

Open Lumina is a simple native macOS app for browsing X-ray studies from local ISO files or local folders. The first release is intentionally narrow: make it easy to open study media, find the relevant images, and view them in a straightforward UI without overreaching into full radiology workstation scope.

iOS is a future direction, but it is not part of the initial delivery. The repository now includes the first native app build, a SwiftPM manifest for fast local verification, synthetic tests, and an Xcode project with native test targets.

## Current Scope

- Native macOS SwiftUI viewer
- Local folder opening
- Local ISO opening through read-only mount flow
- DICOMDIR-first discovery with loose DICOM fallback
- Basic grayscale DICOM rendering with series and image navigation
- No network access, telemetry, cloud sync, or durable study caching by default

## Privacy Posture

- Public-repo safe by default. No real patient data or private study fixtures belong in git.
- User-selected studies are treated as session-scoped inputs, not app-owned durable data.
- ISO access is read-only and temporary. The app cleans up its temporary mount workspace when the study closes.
- The app avoids analytics, third-party services, and secret-bearing config in v0.

## Architecture Direction

- Native Apple-stack application
- SwiftUI-first
- macOS-first for v1
- Shared code with iOS later only where that reuse is justified

## Development

- Native project: `OpenLumina.xcodeproj`
- Fast local build and unit tests: `swift test`
- Native build: `xcodebuild -project OpenLumina.xcodeproj -scheme OpenLumina -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`

## Layout

See [INDEX.md](INDEX.md) for the canonical repository map.
