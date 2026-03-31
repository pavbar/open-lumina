import AppKit
import SwiftUI

@main
struct OpenLuminaApp: App {
    @StateObject private var viewModel = AppViewModel.bootstrap()

    var body: some Scene {
        WindowGroup {
            StudyBrowserView(viewModel: viewModel)
                .frame(minWidth: 1100, minHeight: 720)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    viewModel.closeStudy()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Open Lumina") {
                    AboutWindowController.shared.showWindow()
                }
            }

            CommandGroup(after: .newItem) {
                Button("Open Folder...") {
                    viewModel.openFolder()
                }
                .keyboardShortcut("o")

                Button("Open ISO...") {
                    viewModel.openISO()
                }
                .keyboardShortcut("i")

                Divider()

                Button("Close Study") {
                    viewModel.closeStudy()
                }
                .disabled(!viewModel.hasOpenStudy)

                Divider()

                Button("Export Image…") {
                    exportSelectedImage()
                }
                .keyboardShortcut("e")
                .disabled(!viewModel.canExportSelectedImage)
            }

            CommandMenu("View") {
                Button("Previous Image") {
                    viewModel.selectPreviousImage()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!viewModel.canSelectPreviousImage)

                Button("Next Image") {
                    viewModel.selectNextImage()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!viewModel.canSelectNextImage)

                Divider()

                Button("Zoom To Fit") {
                    viewModel.resetZoom()
                }
                .disabled(!viewModel.hasRenderableImage)
                }
        }
        Settings {
            DiagnosticsSettingsView(diagnosticsStore: viewModel.diagnosticsStore)
        }
    }
}

private struct DiagnosticsSettingsView: View {
    @ObservedObject var diagnosticsStore: DiagnosticLogStore
    @State private var exportStatus = "No diagnostics file exported in this session."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            Text("Diagnostics stay in memory for the current app session only. Export them manually if you want to send a bug report.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Captured events: \(diagnosticsStore.entries.count)")
                .font(.subheadline)

            Button("Export Session Logs…") {
                exportDiagnostics()
            }
                .buttonStyle(.borderedProminent)

            Text(exportStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(width: 440, height: 220, alignment: .topLeading)
    }

    private func exportDiagnostics() {
        do {
            guard let url = try DiagnosticsExportController.exportLogs(from: diagnosticsStore) else {
                exportStatus = "Export cancelled."
                return
            }
            exportStatus = "Saved \(url.lastPathComponent)"
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
        }
    }
}

private extension OpenLuminaApp {
    func exportSelectedImage() {
        _ = try? viewModel.exportSelectedImage()
    }
}

@MainActor
private final class AboutWindowController: NSObject, NSWindowDelegate {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = AboutView(metadata: AboutAppMetadata.current())
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Open Lumina"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.setContentSize(NSSize(width: 420, height: 240))
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
