import AppKit
import Foundation
import UniformTypeIdentifiers

struct AppServices {
    let openPanelService: OpenPanelServicing
    let studyLoader: StudyLoading

    static func bootstrap() -> AppServices {
        if let scenario = ProcessInfo.processInfo.environment["OPEN_LUMINA_UI_TEST_SCENARIO"] {
            return UITestAppServices.bootstrap(scenario: scenario)
        }

        let openPanelService = OpenPanelService()
        let importer = ISOStudyImporter()
        let parser = StudyCatalogLoader()
        let renderer = DICOMImageRenderer()
        let studyLoader = StudyLoader(importer: importer, parser: parser, renderer: renderer)
        return AppServices(openPanelService: openPanelService, studyLoader: studyLoader)
    }
}

protocol OpenPanelServicing {
    @MainActor
    func chooseFolder() -> URL?
    @MainActor
    func chooseISOFile() -> URL?
}

struct OpenPanelService: OpenPanelServicing {
    @MainActor
    func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Study Folder"
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    func chooseISOFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.diskImage]
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Study ISO"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

struct UITestAppServices {
    static func bootstrap(scenario: String) -> AppServices {
        let fixtureRoot = SyntheticStudyFactory.makeUITestFixtureRoot(for: scenario)
        let openPanelService = UITestOpenPanelService(root: fixtureRoot, scenario: scenario)
        let importer = MockISOStudyImporter(root: fixtureRoot)
        let parser = StudyCatalogLoader()
        let renderer = DICOMImageRenderer()
        let studyLoader = StudyLoader(importer: importer, parser: parser, renderer: renderer)
        return AppServices(openPanelService: openPanelService, studyLoader: studyLoader)
    }
}

struct UITestOpenPanelService: OpenPanelServicing {
    let root: URL
    let scenario: String

    func chooseFolder() -> URL? {
        guard scenario == "folder" else { return nil }
        return root.appendingPathComponent("FolderStudy", isDirectory: true)
    }

    func chooseISOFile() -> URL? {
        guard scenario == "iso" else { return nil }
        return root.appendingPathComponent("MockStudy.iso", isDirectory: false)
    }
}
