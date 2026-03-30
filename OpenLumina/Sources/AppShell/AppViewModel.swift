import AppKit
import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var studySource: StudySource?
    @Published private(set) var catalog: StudyCatalog?
    @Published private(set) var selectedSeriesID: String?
    @Published private(set) var selectedImageID: String?
    @Published private(set) var renderedImage: NSImage?
    @Published private(set) var zoomScale: CGFloat = 1.0
    @Published private(set) var statusMessage = "Open a local study folder or ISO image to begin."
    @Published var errorMessage: String?

    private let openPanelService: OpenPanelServicing
    private let studyLoader: StudyLoading
    private var activeSession: StudySession?

    init(
        openPanelService: OpenPanelServicing,
        studyLoader: StudyLoading
    ) {
        self.openPanelService = openPanelService
        self.studyLoader = studyLoader
    }

    static func bootstrap() -> AppViewModel {
        let services = AppServices.bootstrap()
        return AppViewModel(
            openPanelService: services.openPanelService,
            studyLoader: services.studyLoader
        )
    }

    var hasOpenStudy: Bool { catalog != nil }
    var hasRenderableImage: Bool { renderedImage != nil }

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
            Task {
                await loadStudy(from: .folder(url))
            }
        }
    }

    func openISO() {
        if let url = openPanelService.chooseISOFile() {
            Task {
                await loadStudy(from: .iso(url))
            }
        }
    }

    func closeStudy() {
        activeSession?.cleanup()
        activeSession = nil
        studySource = nil
        catalog = nil
        selectedSeriesID = nil
        selectedImageID = nil
        renderedImage = nil
        zoomScale = 1.0
        statusMessage = "Open a local study folder or ISO image to begin."
        errorMessage = nil
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
            if renderedImage == nil {
                statusMessage = "Study loaded, but the selected image is not renderable."
            }
            return true
        } catch {
            closeStudy()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = "No study is open."
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
        }
    }
}
