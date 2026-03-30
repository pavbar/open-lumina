import Foundation

struct StudyCatalogLoader: StudyCatalogParsing {
    private let parser = DICOMParser()

    func catalog(for source: StudySource) throws -> StudyCatalog {
        let root = source.rootURL
        let fileURLs = try resolveImageFileURLs(from: root)

        guard !fileURLs.isEmpty else {
            throw StudyCatalogError.noImagesFound(root)
        }

        let groupedBySeries = Dictionary(grouping: fileURLs) { url in
            loadSeriesTitle(for: url) ?? "Unlabeled Series"
        }

        let series = groupedBySeries.keys.sorted().map { title in
            let urls = groupedBySeries[title, default: []].sorted { $0.lastPathComponent < $1.lastPathComponent }
            return StudySeries(
                id: title.slugified(),
                title: formatSeriesTitle(title),
                subtitle: "\(urls.count) image" + (urls.count == 1 ? "" : "s"),
                images: urls.enumerated().map { index, url in
                    let dataSet = try? parser.parseFile(at: url)
                    let display = loadImageDisplayName(for: url, dataSet: dataSet, fallbackIndex: index + 1)
                    return StudyImage(
                        id: "\(title.slugified())-\(index)",
                        displayName: display.title,
                        subtitle: display.subtitle,
                        fileURL: url
                    )
                }
            )
        }

        return StudyCatalog(
            displayName: formatStudyTitle(for: source),
            subtitle: formatStudySubtitle(for: source),
            series: series
        )
    }

    private func resolveImageFileURLs(from root: URL) throws -> [URL] {
        if let dicomDir = try findDICOMDIR(in: root) {
            let parsed = try parseDICOMDIRReferences(at: dicomDir)
            if !parsed.isEmpty {
                return parsed
            }
        }

        return try scanForDICOMFiles(from: root)
    }

    private func findDICOMDIR(in root: URL) throws -> URL? {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent.uppercased() == "DICOMDIR" {
                return url
            }
        }

        return nil
    }

    private func parseDICOMDIRReferences(at url: URL) throws -> [URL] {
        let dataSet = try parser.parseFile(at: url)
        guard let sequence = dataSet.elementsByTag[0x00041220] else {
            return []
        }

        var imageURLs: [URL] = []
        let root = url.deletingLastPathComponent()

        for item in sequence.children {
            let recordType = item.children.first(where: { $0.tag == 0x00041430 }).flatMap {
                String(data: $0.value, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            }
            guard recordType == "IMAGE" || recordType == "SERIES" || recordType == "STUDY" else {
                continue
            }

            guard let fileIDs = item.children.first(where: { $0.tag == 0x00041500 }) else {
                continue
            }

            let components = decodeFileIDComponents(from: fileIDs.value)
            guard !components.isEmpty else { continue }
            let resolved = components.reduce(root) { partial, component in
                partial.appendingPathComponent(component)
            }
            if FileManager.default.fileExists(atPath: resolved.path), parser.fileLooksLikeDICOM(resolved) {
                imageURLs.append(resolved)
            }
        }

        return Array(Set(imageURLs)).sorted { $0.path < $1.path }
    }

    private func decodeFileIDComponents(from data: Data) -> [String] {
        let raw = String(decoding: data, as: UTF8.self)
        let trimmed = raw.replacingOccurrences(of: "\0", with: "")
        if trimmed.contains("\\") {
            return trimmed
                .split(separator: "\\")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        let componentWidth = 8
        let count = data.count / componentWidth
        return (0..<count).compactMap { index in
            let start = index * componentWidth
            let end = min(start + componentWidth, data.count)
            let text = String(decoding: data.subdata(in: start..<end), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            return text.isEmpty ? nil : text
        }
    }

    private func scanForDICOMFiles(from root: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var urls: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            if parser.fileLooksLikeDICOM(url) {
                urls.append(url)
            }
        }
        return urls
    }

    private func loadSeriesTitle(for url: URL) -> String? {
        guard let dataSet = try? parser.parseFile(at: url) else { return nil }
        return dataSet.string(for: 0x0008103E) ?? dataSet.string(for: 0x00200011)
    }

    private func loadImageDisplayName(for url: URL, dataSet: DICOMDataSet?, fallbackIndex: Int) -> (title: String, subtitle: String) {
        let instanceNumber = dataSet?.string(for: 0x00200013)
        let viewPosition = dataSet?.string(for: 0x00185101)
        let laterality = dataSet?.string(for: 0x00200060)
        let fallbackTitle = "Image \(fallbackIndex)"

        let title: String
        if let viewPosition, !viewPosition.isEmpty {
            title = viewPosition
        } else if let instanceNumber, let numeric = Int(instanceNumber) {
            title = "Image \(numeric)"
        } else {
            title = fallbackTitle
        }

        let subtitleParts = [
            laterality?.emptyToNil(),
            instanceNumber.flatMap { value in
                Int(value).map { "Instance \($0)" }
            },
            compactFilename(for: url)
        ].compactMap { $0 }

        return (title, subtitleParts.joined(separator: " • "))
    }

    private func formatStudyTitle(for source: StudySource) -> String {
        switch source {
        case .folder(let url):
            return prettifyFilename(url.deletingPathExtension().lastPathComponent)
        case .mountedISO(let imageURL, _):
            return prettifyFilename(imageURL.deletingPathExtension().lastPathComponent)
        }
    }

    private func formatStudySubtitle(for source: StudySource) -> String {
        switch source {
        case .folder:
            return "Local folder study"
        case .mountedISO(let imageURL, _):
            return "ISO study • \(imageURL.lastPathComponent)"
        }
    }

    private func formatSeriesTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let numeric = Int(trimmed) {
            return "Series \(numeric)"
        }
        if trimmed.count > 32, trimmed.contains(".") {
            return "Unlabeled Series"
        }
        return prettifyFilename(trimmed)
    }

    private func prettifyFilename(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return "Open Lumina Study" }
        if normalized.count > 48 {
            return String(normalized.prefix(48)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return normalized
    }

    private func compactFilename(for url: URL) -> String {
        let name = url.lastPathComponent
        if name.count > 20 {
            return String(name.prefix(20)) + "…"
        }
        return name
    }
}

private extension String {
    func slugified() -> String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    func emptyToNil() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
