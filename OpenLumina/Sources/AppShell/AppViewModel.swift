import Combine
import CoreGraphics
import Dispatch
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var studySource: StudySource?
    @Published private(set) var catalog: StudyCatalog?
    @Published private(set) var selectedSeriesID: String?
    @Published private(set) var selectedImageID: String?
    @Published private(set) var renderedImage: CGImage?
    @Published private(set) var seriesPreviewImages: [String: CGImage] = [:]
    @Published private(set) var imagePreviewImages: [String: CGImage] = [:]
    @Published private(set) var zoomScale: CGFloat = 1.0
    @Published private(set) var statusMessage = "Open a local study folder or ISO image to begin."
    @Published var errorMessage: String?

    let diagnosticsStore: DiagnosticLogStore
    private let openPanelService: OpenPanelServicing
    private let studyLoader: StudyLoading
    private let imageExportService: ImageExporting
    private var activeSession: StudySession?
    private var previewGenerationToken = UUID()

    init(
        openPanelService: OpenPanelServicing,
        studyLoader: StudyLoading,
        imageExportService: ImageExporting,
        diagnosticsStore: DiagnosticLogStore = DiagnosticLogStore()
    ) {
        self.openPanelService = openPanelService
        self.studyLoader = studyLoader
        self.imageExportService = imageExportService
        self.diagnosticsStore = diagnosticsStore
    }

    static func bootstrap() -> AppViewModel {
        let services = AppServices.bootstrap()
        return AppViewModel(
            openPanelService: services.openPanelService,
            studyLoader: services.studyLoader,
            imageExportService: services.imageExportService,
            diagnosticsStore: services.diagnosticsStore
        )
    }

    var hasOpenStudy: Bool { catalog != nil }
    var hasRenderableImage: Bool { renderedImage != nil }
    var canExportSelectedImage: Bool { renderedImage != nil && selectedImage != nil }

    func previewImage(forSeriesID seriesID: String) -> CGImage? {
        seriesPreviewImages[seriesID]
    }

    func previewImage(forImageID imageID: String) -> CGImage? {
        imagePreviewImages[imageID]
    }

    var selectedSeries: StudySeries? {
        guard
            let catalog,
            let selectedSeriesID
        else { return nil }
        return catalog.series.first(where: { $0.id == selectedSeriesID })
    }

    var selectedImage: StudyImage? {
        guard
            let selectedSeries,
            let selectedImageID
        else { return nil }
        return selectedSeries.images.first(where: { $0.id == selectedImageID })
    }

    var canSelectPreviousImage: Bool {
        guard let currentIndex = selectedImageIndex else { return false }
        return currentIndex > 0
    }

    var canSelectNextImage: Bool {
        guard
            let selectedSeries,
            let currentIndex = selectedImageIndex
        else { return false }
        return currentIndex < selectedSeries.images.count - 1
    }

    func openFolder() {
        if let url = openPanelService.chooseFolder() {
            diagnosticsStore.record("open_requested", details: ["source": "folder"])
            Task {
                await loadStudy(from: .folder(url))
            }
        }
    }

    func openISO() {
        if let url = openPanelService.chooseISOFile() {
            diagnosticsStore.record("open_requested", details: ["source": "iso"])
            Task {
                await loadStudy(from: .iso(url))
            }
        }
    }

    func closeStudy() {
        diagnosticsStore.record("study_close_requested")
        activeSession?.cleanup()
        activeSession = nil
        studySource = nil
        catalog = nil
        selectedSeriesID = nil
        selectedImageID = nil
        renderedImage = nil
        seriesPreviewImages = [:]
        imagePreviewImages = [:]
        previewGenerationToken = UUID()
        zoomScale = 1.0
        statusMessage = "Open a local study folder or ISO image to begin."
        errorMessage = nil
    }

    @discardableResult
    func exportSelectedImage() throws -> URL? {
        guard let renderedImage, let selectedImage else {
            throw ImageExportError.noRenderableImage
        }

        let url = try imageExportService.exportImage(renderedImage, suggestedName: selectedImage.displayName)
        if let url {
            statusMessage = "Saved \(url.lastPathComponent)"
            diagnosticsStore.record(
                "image_export_succeeded",
                details: [
                    "format": url.pathExtension.lowercased(),
                    "file": url.lastPathComponent
                ]
            )
        } else {
            statusMessage = "Export cancelled."
        }
        return url
    }

    func selectSeries(_ seriesID: String) {
        guard let catalog, let series = catalog.series.first(where: { $0.id == seriesID }) else { return }
        selectedSeriesID = series.id
        selectedImageID = series.images.first?.id
        renderSelectedImageIfPossible()
    }

    func selectImage(_ imageID: String) {
        selectedImageID = imageID
        renderSelectedImageIfPossible()
    }

    func selectPreviousImage() {
        guard
            let selectedSeries,
            let currentIndex = selectedImageIndex,
            currentIndex > 0
        else { return }
        selectedImageID = selectedSeries.images[currentIndex - 1].id
        renderSelectedImageIfPossible()
    }

    func selectNextImage() {
        guard
            let selectedSeries,
            let currentIndex = selectedImageIndex,
            currentIndex < selectedSeries.images.count - 1
        else { return }
        selectedImageID = selectedSeries.images[currentIndex + 1].id
        renderSelectedImageIfPossible()
    }

    func resetZoom() {
        zoomScale = 1.0
    }

    func updateZoom(_ value: CGFloat) {
        zoomScale = min(max(value, 0.25), 4.0)
    }

    @discardableResult
    func loadStudy(from input: StudyInput) async -> Bool {
        do {
            diagnosticsStore.record("study_load_started", details: ["source": input.diagnosticLabel])
            closeStudy()
            let session = try studyLoader.loadStudy(from: input)
            activeSession = session
            studySource = session.source
            catalog = session.catalog
            statusMessage = session.catalog.displayName

            if let firstSeries = session.catalog.series.first {
                selectedSeriesID = firstSeries.id
                selectedImageID = firstSeries.images.first?.id
            }

            renderSelectedImageIfPossible()
            schedulePreviewGeneration(for: session.catalog)
            if renderedImage == nil {
                statusMessage = "Study loaded, but the selected image is not renderable."
            }
            diagnosticsStore.record(
                "study_load_succeeded",
                details: [
                    "source": input.diagnosticLabel,
                    "series": "\(session.catalog.series.count)",
                    "images": "\(session.catalog.imageCount)"
                ]
            )
            return true
        } catch {
            closeStudy()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = "No study is open."
            diagnosticsStore.record(
                "study_load_failed",
                details: [
                    "source": input.diagnosticLabel,
                    "reason": String(describing: type(of: error))
                ]
            )
            return false
        }
    }

    private var selectedImageIndex: Int? {
        guard
            let selectedSeries,
            let selectedImageID
        else { return nil }
        return selectedSeries.images.firstIndex(where: { $0.id == selectedImageID })
    }

    private func renderSelectedImageIfPossible() {
        guard let selectedImage else {
            renderedImage = nil
            return
        }

        do {
            renderedImage = try studyLoader.renderImage(at: selectedImage.fileURL)
            errorMessage = nil
        } catch {
            renderedImage = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            diagnosticsStore.record(
                "image_render_failed",
                details: ["reason": String(describing: type(of: error))]
            )
        }
    }

    private func schedulePreviewGeneration(for catalog: StudyCatalog) {
        let token = UUID()
        previewGenerationToken = token

        let initialRenderedImage = renderedImage
        let selectedSeriesID = selectedSeriesID
        let selectedImageID = selectedImageID
        let loader = studyLoader

        if
            let selectedSeriesID,
            let selectedImageID,
            let initialRenderedImage
        {
            seriesPreviewImages = [selectedSeriesID: initialRenderedImage]
            imagePreviewImages = [selectedImageID: initialRenderedImage]
        } else {
            seriesPreviewImages = [:]
            imagePreviewImages = [:]
        }

        DispatchQueue.global(qos: .utility).async { [catalog] in
            for series in catalog.series {
                guard let firstImage = series.images.first else { continue }

                let firstRendered: CGImage?
                if series.id == selectedSeriesID, let initialRenderedImage {
                    firstRendered = initialRenderedImage
                } else if firstImage.id == selectedImageID, let initialRenderedImage {
                    firstRendered = initialRenderedImage
                } else {
                    firstRendered = try? loader.renderImage(at: firstImage.fileURL)
                }

                if let firstRendered {
                    DispatchQueue.main.async {
                        guard self.previewGenerationToken == token else { return }
                        if self.seriesPreviewImages[series.id] == nil {
                            self.seriesPreviewImages[series.id] = firstRendered
                        }
                        if self.imagePreviewImages[firstImage.id] == nil {
                            self.imagePreviewImages[firstImage.id] = firstRendered
                        }
                    }
                }

                for image in series.images.dropFirst().prefix(5) {
                    guard image.id != selectedImageID,
                          let rendered = try? loader.renderImage(at: image.fileURL) else { continue }
                    DispatchQueue.main.async {
                        guard self.previewGenerationToken == token else { return }
                        if self.imagePreviewImages[image.id] == nil {
                            self.imagePreviewImages[image.id] = rendered
                        }
                    }
                }
            }
        }
    }
}
