import XCTest
@testable import OpenLumina

final class OpenLuminaTests: XCTestCase {
    func testDICOMDIRFirstCatalogDiscoveryFindsSyntheticImages() throws {
        let root = try makeFixtureRoot(named: "Folder Fixture")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Folder Fixture")

        let loader = StudyCatalogLoader()
        let catalog = try loader.catalog(for: .folder(root))

        XCTAssertEqual(catalog.series.count, 1)
        XCTAssertEqual(catalog.series.first?.images.count, 2)
        XCTAssertEqual(catalog.displayName, "Folder Fixture")
        XCTAssertEqual(catalog.subtitle, "Local folder study")
    }

    func testFallbackScanningFindsDICOMFilesWithoutDICOMDIR() throws {
        let root = try makeFixtureRoot(named: "Scan Fixture")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Scan Fixture")
        try FileManager.default.removeItem(at: root.appendingPathComponent("DICOMDIR"))

        let loader = StudyCatalogLoader()
        let catalog = try loader.catalog(for: .folder(root))

        XCTAssertEqual(catalog.series.first?.images.count, 2)
    }

    func testDisplayNamesAreHumanFriendlyInsteadOfRawUIDs() throws {
        let root = try makeFixtureRoot(named: "sample-study-a")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "sample-study-a")

        let catalog = try StudyCatalogLoader().catalog(for: .folder(root))
        let series = try XCTUnwrap(catalog.series.first)
        let image = try XCTUnwrap(series.images.first)

        XCTAssertEqual(catalog.displayName, "sample study a")
        XCTAssertEqual(series.title, "PA Chest")
        XCTAssertEqual(image.displayName, "Image 1")
        XCTAssertTrue(image.subtitle.contains("IMAGE0001"))
    }

    func testISOStudyLoaderCleansUpMountedWorkspace() throws {
        let mountRoot = try makeFixtureRoot()
        try SyntheticStudyFactory.writeSyntheticStudy(to: mountRoot, studyName: "Mounted Fixture")

        let importer = TestISOImporter(rootURL: mountRoot)
        let studyLoader = StudyLoader(importer: importer, parser: StudyCatalogLoader(), renderer: DICOMImageRenderer())
        let session = try studyLoader.loadStudy(from: .iso(URL(fileURLWithPath: "/tmp/mock.iso")))

        XCTAssertTrue(FileManager.default.fileExists(atPath: mountRoot.path))
        session.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: mountRoot.path))
    }

    func testDICOMRendererProducesImageForSyntheticFixture() throws {
        let root = try makeFixtureRoot()
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Render Fixture")
        let imageURL = root.appendingPathComponent("SERIES1/IMAGE0001")

        let image = try DICOMImageRenderer().renderImage(at: imageURL)
        XCTAssertEqual(image.width, 16)
        XCTAssertEqual(image.height, 16)
    }

    @MainActor
    func testViewModelNavigatesBetweenImages() async throws {
        let root = try makeFixtureRoot()
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Navigation Fixture")
        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: root, isoURL: nil),
            studyLoader: StudyLoader(importer: TestISOImporter(rootURL: root), parser: StudyCatalogLoader(), renderer: DICOMImageRenderer()),
            imageExportService: StubImageExportService()
        )

        let loaded = await viewModel.loadStudy(from: .folder(root))
        XCTAssertTrue(loaded)
        XCTAssertEqual(viewModel.selectedSeries?.images.count, 2)

        let firstID = try XCTUnwrap(viewModel.selectedImage?.id)
        viewModel.selectNextImage()
        XCTAssertNotEqual(viewModel.selectedImage?.id, firstID)
        viewModel.selectPreviousImage()
        XCTAssertEqual(viewModel.selectedImage?.id, firstID)
    }

    @MainActor
    func testClosingStudyCleansMountedWorkspace() async throws {
        let root = try makeFixtureRoot(named: "Mounted Cleanup")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Mounted Cleanup")

        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: nil, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: root),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: StubImageExportService()
        )

        let loaded = await viewModel.loadStudy(from: .iso(URL(fileURLWithPath: "/tmp/mock.iso")))
        XCTAssertTrue(loaded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))

        viewModel.closeStudy()

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        XCTAssertNil(viewModel.catalog)
        XCTAssertNil(viewModel.selectedImage)
    }

    @MainActor
    func testLoadingStudyGeneratesPreviewImages() async throws {
        let root = try makeFixtureRoot(named: "Preview Fixture")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Preview Fixture")

        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: root, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: root),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: StubImageExportService()
        )

        let loaded = await viewModel.loadStudy(from: .folder(root))
        XCTAssertTrue(loaded)

        let seriesID = try XCTUnwrap(viewModel.selectedSeries?.id)
        let imageID = try XCTUnwrap(viewModel.selectedImage?.id)

        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if viewModel.previewImage(forSeriesID: seriesID) != nil,
               viewModel.previewImage(forImageID: imageID) != nil {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTFail("Expected preview images to be generated asynchronously.")
    }

    func testUnsupportedStudyProducesError() throws {
        let root = try makeFixtureRoot()
        try "not a dicom file".data(using: .utf8)?.write(to: root.appendingPathComponent("plain.txt"))

        XCTAssertThrowsError(try StudyCatalogLoader().catalog(for: .folder(root))) { error in
            XCTAssertTrue(error.localizedDescription.contains("No renderable DICOM images"))
        }
    }

    func testSyntheticFixturesContainNoSecretsLikeValues() throws {
        let root = try makeFixtureRoot()
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Privacy Fixture")
        let payload = try Data(contentsOf: root.appendingPathComponent("DICOMDIR"))
        let text = String(decoding: payload, as: UTF8.self).lowercased()

        XCTAssertFalse(text.contains("token"))
        XCTAssertFalse(text.contains("secret"))
        XCTAssertFalse(text.contains("patient"))
    }

    @MainActor
    func testDiagnosticExportRedactsPaths() {
        let store = DiagnosticLogStore(now: { Date(timeIntervalSince1970: 0) })
        store.record(
            "iso_mount_failed",
            details: [
                "reason": "resource_busy",
                "path": "/redacted/example-study.iso"
            ]
        )

        let export = store.exportText()

        XCTAssertTrue(export.contains("iso_mount_failed"))
        XCTAssertTrue(export.contains("reason=resource_busy"))
        XCTAssertTrue(export.contains("path=redacted-path"))
        XCTAssertFalse(export.contains("/Users/redacted-user"))
    }

    @MainActor
    func testExportAvailabilityTracksRenderableImageSelection() async throws {
        let root = try makeFixtureRoot(named: "Export Fixture")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Export Fixture")
        let exportService = StubImageExportService()
        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: root, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: root),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: exportService
        )

        XCTAssertFalse(viewModel.canExportSelectedImage)

        let loaded = await viewModel.loadStudy(from: .folder(root))
        XCTAssertTrue(loaded)
        XCTAssertTrue(viewModel.canExportSelectedImage)
    }

    @MainActor
    func testExportSelectedImageUsesSanitizedDisplayNameAndUpdatesStatus() async throws {
        let root = try makeFixtureRoot(named: "Export Display Name")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Export Display Name")
        let exportService = StubImageExportService()
        exportService.nextResult = URL(fileURLWithPath: "/tmp/Image-1.png")
        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: root, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: root),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: exportService
        )

        let loaded = await viewModel.loadStudy(from: .folder(root))
        XCTAssertTrue(loaded)

        let url = try viewModel.exportSelectedImage()
        XCTAssertEqual(url?.lastPathComponent, "Image-1.png")
        XCTAssertEqual(exportService.lastSuggestedName, "Image 1")
        XCTAssertEqual(viewModel.statusMessage, "Saved Image-1.png")
    }

    @MainActor
    func testExportSelectedImageFailsWithoutRenderableImage() throws {
        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: nil, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: URL(fileURLWithPath: "/tmp/unneeded")),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: StubImageExportService()
        )

        XCTAssertThrowsError(try viewModel.exportSelectedImage()) { error in
            XCTAssertEqual(error as? ImageExportError, .noRenderableImage)
        }
    }

    @MainActor
    func testExportFailureSetsDedicatedExportErrorState() async throws {
        let root = try makeFixtureRoot(named: "Export Failure Fixture")
        try SyntheticStudyFactory.writeSyntheticStudy(to: root, studyName: "Export Failure Fixture")
        let exportService = ThrowingImageExportService(error: ImageExportError.failedToFinalize)
        let viewModel = AppViewModel(
            openPanelService: StubOpenPanelService(folderURL: root, isoURL: nil),
            studyLoader: StudyLoader(
                importer: TestISOImporter(rootURL: root),
                parser: StudyCatalogLoader(),
                renderer: DICOMImageRenderer()
            ),
            imageExportService: exportService
        )

        let loaded = await viewModel.loadStudy(from: .folder(root))
        XCTAssertTrue(loaded)

        XCTAssertThrowsError(try viewModel.exportSelectedImage()) { error in
            XCTAssertEqual(error as? ImageExportError, .failedToFinalize)
        }
        XCTAssertEqual(viewModel.exportErrorMessage, "Open Lumina could not finish writing the exported image.")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testImageExportNamingSanitizesFilenameStem() {
        XCTAssertEqual(ImageExportNaming.sanitizedBaseName(from: " PA Chest / View 1 "), "PA-Chest-View-1")
        XCTAssertEqual(ImageExportNaming.sanitizedBaseName(from: ""), "OpenLumina-Image")
    }

    func testImageExportNamingBuildsDestinationURLForChosenFormat() {
        let directory = URL(fileURLWithPath: "/tmp/open-lumina-export-tests", isDirectory: true)
        let pngURL = ImageExportNaming.destinationURL(for: directory, baseName: "Image-1", format: .png)
        let jpegURL = ImageExportNaming.destinationURL(for: directory, baseName: "Image-1", format: .jpeg)

        XCTAssertEqual(pngURL.lastPathComponent, "Image-1.png")
        XCTAssertEqual(jpegURL.lastPathComponent, "Image-1.jpg")
    }

    @MainActor
    func testImageExportServiceNormalizesSelectedDestinationExtensionBeforeWriting() throws {
        let selection = ImageExportSelection(
            destinationURL: URL(fileURLWithPath: "/tmp/open-lumina-export-tests/Custom Study.png"),
            format: .jpeg
        )
        let writer = RecordingImageWriter()
        let service = ImageExportService(
            selectionService: StubImageExportSelectionService(selection: selection),
            imageWriter: writer
        )

        let exportedURL = try service.exportImage(makeTestImage(), suggestedName: "Custom Study")

        XCTAssertEqual(writer.lastDestinationURL?.lastPathComponent, "Custom Study.jpg")
        XCTAssertEqual(writer.lastFormat, .jpeg)
        XCTAssertEqual(exportedURL?.lastPathComponent, "Custom Study.jpg")
    }

    func testImageExportNamingPreservesUserBasenameWhenSwitchingFormats() {
        XCTAssertEqual(ImageExportNaming.filename(for: "Custom Study.png", format: .jpeg), "Custom Study.jpg")
        XCTAssertEqual(ImageExportNaming.filename(for: "Custom Study.jpeg", format: .png), "Custom Study.png")
        XCTAssertEqual(ImageExportNaming.filename(for: "Custom Study", format: .png), "Custom Study.png")
        XCTAssertEqual(ImageExportNaming.filename(for: "scan.final.png", format: .jpeg), "scan.final.jpg")
        XCTAssertEqual(ImageExportNaming.baseName(from: "Custom Study.jpeg"), "Custom Study")
        XCTAssertEqual(ImageExportNaming.baseName(from: "scan.final.png"), "scan.final")
        XCTAssertEqual(ImageExportNaming.baseName(from: "scan.final"), "scan.final")
    }

    func testImageWriterProducesPNGData() throws {
        let url = temporaryFileURL(ext: "png")
        try CGImageWriter().write(makeTestImage(), to: url, format: .png)
        let data = try Data(contentsOf: url)
        XCTAssertTrue(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    func testImageWriterProducesJPEGData() throws {
        let url = temporaryFileURL(ext: "jpg")
        try CGImageWriter().write(makeTestImage(), to: url, format: .jpeg)
        let data = try Data(contentsOf: url)
        XCTAssertTrue(data.starts(with: [0xFF, 0xD8, 0xFF]))
    }

    func testImageWriterFailsForInvalidDestination() {
        let url = URL(fileURLWithPath: "/dev/null/missing/output.png")
        XCTAssertThrowsError(try CGImageWriter().write(makeTestImage(), to: url, format: .png))
    }

    private func makeFixtureRoot(named name: String = UUID().uuidString) throws -> URL {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lumina-tests-\(UUID().uuidString)", isDirectory: true)
        let root = container.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: container)
        }
        return root
    }

    private func temporaryFileURL(ext: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lumina-export-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root.appendingPathComponent("sample.\(ext)")
    }

    private func makeTestImage() -> CGImage {
        let width = 2
        let height = 2
        let bytesPerRow = width
        let pixels: [UInt8] = [0, 120, 180, 255]
        let data = Data(pixels) as CFData
        let provider = CGDataProvider(data: data)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}

private struct TestISOImporter: ISOImporting {
    let rootURL: URL

    func mountISO(at url: URL) throws -> DisposableStudyMount {
        DisposableStudyMount(rootURL: rootURL) {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }
}

private struct StubOpenPanelService: OpenPanelServicing {
    let folderURL: URL?
    let isoURL: URL?

    func chooseFolder() -> URL? { folderURL }
    func chooseISOFile() -> URL? { isoURL }
}

@MainActor
private final class StubImageExportService: ImageExporting {
    var nextResult: URL?
    var lastSuggestedName: String?

    func exportImage(_ image: CGImage, suggestedName: String) throws -> URL? {
        lastSuggestedName = suggestedName
        return nextResult
    }
}

private final class ThrowingImageExportService: ImageExporting {
    let error: Error

    init(error: Error) {
        self.error = error
    }

    func exportImage(_ image: CGImage, suggestedName: String) throws -> URL? {
        throw error
    }
}

private struct StubImageExportSelectionService: ImageExportSelecting {
    let selection: ImageExportSelection?

    @MainActor
    func chooseExportDestination(suggestedBaseName: String) -> ImageExportSelection? {
        selection
    }
}

private final class RecordingImageWriter: RenderedImageWriting {
    private(set) var lastDestinationURL: URL?
    private(set) var lastFormat: ImageExportFormat?

    func write(_ image: CGImage, to url: URL, format: ImageExportFormat) throws {
        lastDestinationURL = url
        lastFormat = format
    }
}
