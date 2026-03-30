import CoreGraphics
import Foundation

struct StudyLoader: StudyLoading {
    let importer: ISOImporting
    let parser: StudyCatalogParsing
    let renderer: ImageRendering

    func loadStudy(from input: StudyInput) throws -> StudySession {
        switch input {
        case .folder(let url):
            let source = StudySource.folder(url)
            let catalog = try parser.catalog(for: source)
            return StudySession(source: source, catalog: catalog, cleanup: { })

        case .iso(let url):
            let mount = try importer.mountISO(at: url)
            let source = StudySource.mountedISO(imageURL: url, mountURL: mount.rootURL)
            let catalog = try parser.catalog(for: source)
            return StudySession(source: source, catalog: catalog, cleanup: mount.cleanup)
        }
    }

    func renderImage(at url: URL) throws -> CGImage {
        try renderer.renderImage(at: url)
    }
}
