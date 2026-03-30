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
    }
}
