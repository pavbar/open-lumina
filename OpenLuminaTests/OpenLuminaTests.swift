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
            studyLoader: StudyLoader(importer: TestISOImporter(rootURL: root), parser: StudyCatalogLoader(), renderer: DICOMImageRenderer())
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
            )
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
            )
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
