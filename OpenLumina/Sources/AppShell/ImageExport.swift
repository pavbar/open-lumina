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

    static func normalizedDestinationURL(for url: URL, format: ImageExportFormat) -> URL {
        destinationURL(
            for: url.deletingLastPathComponent(),
            baseName: baseName(from: url.lastPathComponent),
            format: format
        )
    }

    static func filename(for fieldValue: String, format: ImageExportFormat) -> String {
        let baseName = baseName(from: fieldValue)
        return "\(baseName).\(format.fileExtension)"
    }

    static func baseName(from fieldValue: String) -> String {
        let trimmed = fieldValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "OpenLumina-Image"
        }

        let url = URL(fileURLWithPath: trimmed)
        let extensionLowercased = url.pathExtension.lowercased()
        guard recognizedExtensions.contains(extensionLowercased) else {
            return url.lastPathComponent
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        return baseName.isEmpty ? "OpenLumina-Image" : baseName
    }

    private static let recognizedExtensions: Set<String> = ["png", "jpg", "jpeg"]
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
        panel.nameFieldStringValue = ImageExportNaming.filename(for: suggestedBaseName, format: .png)

        accessoryStack.orientation = .horizontal
        accessoryStack.spacing = 8
        accessoryStack.alignment = .centerY
        picker.addItems(withTitles: ImageExportFormat.allCases.map(\.displayName))
        picker.selectItem(at: 0)
        panel.accessoryView = accessoryStack

        let controller = ImageExportPanelDelegate(panel: panel, picker: picker)
        picker.target = controller
        picker.action = #selector(ImageExportPanelDelegate.formatChanged(_:))
        panel.delegate = controller
        objc_setAssociatedObject(panel, Unmanaged.passUnretained(panel).toOpaque(), controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let format = controller.selectedFormat
        return ImageExportSelection(destinationURL: url, format: format)
    }
}

@MainActor
private final class ImageExportPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    private weak var panel: NSSavePanel?
    private let picker: NSPopUpButton

    var selectedFormat: ImageExportFormat {
        ImageExportFormat.allCases[max(0, picker.indexOfSelectedItem)]
    }

    init(panel: NSSavePanel, picker: NSPopUpButton) {
        self.panel = panel
        self.picker = picker
    }

    @objc func formatChanged(_ sender: Any?) {
        guard let panel else { return }
        panel.nameFieldStringValue = ImageExportNaming.filename(
            for: panel.nameFieldStringValue,
            format: selectedFormat
        )
    }

    func panel(_ sender: Any, userEnteredFilename filename: String, confirmed okFlag: Bool) -> String? {
        guard okFlag else { return filename }
        return ImageExportNaming.filename(for: filename, format: selectedFormat)
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
        let destinationURL = ImageExportNaming.normalizedDestinationURL(for: selection.destinationURL, format: selection.format)
        try imageWriter.write(image, to: destinationURL, format: selection.format)
        return destinationURL
    }
}
