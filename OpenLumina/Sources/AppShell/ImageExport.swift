import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ObjectiveC
import UniformTypeIdentifiers

enum ImageExportFormat: String, CaseIterable, Equatable {
    case png
    case jpeg

    var contentType: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        }
    }

    var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        }
    }

    var displayName: String {
        switch self {
        case .png:
            return "PNG"
        case .jpeg:
            return "JPEG"
        }
    }
}

struct ImageExportSelection: Equatable {
    let destinationURL: URL
    let format: ImageExportFormat
}

protocol ImageExportSelecting {
    @MainActor
    func chooseExportDestination(suggestedBaseName: String) -> ImageExportSelection?
}

protocol RenderedImageWriting {
    func write(_ image: CGImage, to url: URL, format: ImageExportFormat) throws
}

enum ImageExportError: LocalizedError, Equatable {
    case noRenderableImage
    case failedToCreateDestination
    case failedToFinalize

    var errorDescription: String? {
        switch self {
        case .noRenderableImage:
            return "Select a renderable image before exporting."
        case .failedToCreateDestination:
            return "Unable to create the export file."
        case .failedToFinalize:
            return "Open Lumina could not finish writing the exported image."
        }
    }
}

enum ImageExportNaming {
    static func sanitizedBaseName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "OpenLumina-Image" : trimmed
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let replaced = source.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(replaced)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return collapsed.isEmpty ? "OpenLumina-Image" : collapsed
    }

    static func destinationURL(for directoryURL: URL, baseName: String, format: ImageExportFormat) -> URL {
        directoryURL.appendingPathComponent(baseName).appendingPathExtension(format.fileExtension)
    }
}

struct ImageExportPanelService: ImageExportSelecting {
    @MainActor
    func chooseExportDestination(suggestedBaseName: String) -> ImageExportSelection? {
        let panel = NSSavePanel()
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        let accessoryLabel = NSTextField(labelWithString: "Format:")
        let accessoryStack = NSStackView(views: [accessoryLabel, picker])

        panel.canCreateDirectories = true
        panel.allowedContentTypes = ImageExportFormat.allCases.map(\.contentType)
        panel.allowsOtherFileTypes = false
        panel.prompt = "Export Image"
        panel.isExtensionHidden = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.nameFieldStringValue = ImageExportNaming.destinationURL(
            for: panel.directoryURL ?? FileManager.default.homeDirectoryForCurrentUser,
            baseName: suggestedBaseName,
            format: .png
        ).lastPathComponent

        accessoryStack.orientation = .horizontal
        accessoryStack.spacing = 8
        accessoryStack.alignment = .centerY
        picker.addItems(withTitles: ImageExportFormat.allCases.map(\.displayName))
        picker.selectItem(at: 0)
        panel.accessoryView = accessoryStack

        picker.action = #selector(ImageExportAccessoryController.formatChanged(_:))
        let controller = ImageExportAccessoryController(
            panel: panel,
            picker: picker,
            suggestedBaseName: suggestedBaseName
        )
        picker.target = controller
        objc_setAssociatedObject(panel, Unmanaged.passUnretained(panel).toOpaque(), controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let format = formatForURL(url)
        return ImageExportSelection(destinationURL: url, format: format)
    }

    private func formatForURL(_ url: URL) -> ImageExportFormat {
        let ext = url.pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" {
            return .jpeg
        }
        return .png
    }
}

@MainActor
private final class ImageExportAccessoryController: NSObject {
    private weak var panel: NSSavePanel?
    private let picker: NSPopUpButton
    private let suggestedBaseName: String

    init(panel: NSSavePanel, picker: NSPopUpButton, suggestedBaseName: String) {
        self.panel = panel
        self.picker = picker
        self.suggestedBaseName = suggestedBaseName
    }

    @objc func formatChanged(_ sender: Any?) {
        guard
            let panel
        else { return }

        let selectedIndex = max(0, picker.indexOfSelectedItem)
        let format = ImageExportFormat.allCases[selectedIndex]
        let directoryURL = panel.directoryURL ?? FileManager.default.homeDirectoryForCurrentUser
        panel.nameFieldStringValue = ImageExportNaming.destinationURL(
            for: directoryURL,
            baseName: suggestedBaseName,
            format: format
        ).lastPathComponent
    }
}

struct CGImageWriter: RenderedImageWriting {
    func write(_ image: CGImage, to url: URL, format: ImageExportFormat) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.contentType.identifier as CFString, 1, nil) else {
            throw ImageExportError.failedToCreateDestination
        }

        let properties: CFDictionary?
        switch format {
        case .png:
            properties = nil
        case .jpeg:
            properties = [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary
        }

        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageExportError.failedToFinalize
        }
    }
}

protocol ImageExporting {
    @MainActor
    func exportImage(_ image: CGImage, suggestedName: String) throws -> URL?
}

struct ImageExportService: ImageExporting {
    let selectionService: ImageExportSelecting
    let imageWriter: RenderedImageWriting

    @MainActor
    func exportImage(_ image: CGImage, suggestedName: String) throws -> URL? {
        let baseName = ImageExportNaming.sanitizedBaseName(from: suggestedName)
        guard let selection = selectionService.chooseExportDestination(suggestedBaseName: baseName) else {
            return nil
        }
        try imageWriter.write(image, to: selection.destinationURL, format: selection.format)
        return selection.destinationURL
    }
}
