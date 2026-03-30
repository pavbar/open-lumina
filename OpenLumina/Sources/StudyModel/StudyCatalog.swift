import CoreGraphics
import Foundation

struct StudyCatalog: Equatable {
    let displayName: String
    let subtitle: String
    let series: [StudySeries]

    var imageCount: Int {
        series.reduce(0) { $0 + $1.images.count }
    }
}

struct StudySeries: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let images: [StudyImage]
}

struct StudyImage: Identifiable, Equatable {
    let id: String
    let displayName: String
    let subtitle: String
    let fileURL: URL
}

protocol StudyCatalogParsing {
    func catalog(for source: StudySource) throws -> StudyCatalog
}

protocol StudyLoading {
    func loadStudy(from input: StudyInput) throws -> StudySession
    func renderImage(at url: URL) throws -> CGImage
}
