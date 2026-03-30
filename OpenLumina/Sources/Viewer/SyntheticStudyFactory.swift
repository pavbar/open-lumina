import Foundation

enum SyntheticStudyFactory {
    static func makeUITestFixtureRoot(for scenario: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lumina-ui-\(scenario)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? createFixtureSet(at: root)
        return root
    }

    static func createFixtureSet(at root: URL) throws {
        let folderStudy = root.appendingPathComponent("FolderStudy", isDirectory: true)
        let isoStudy = root.appendingPathComponent("MountedISO", isDirectory: true)
        try FileManager.default.createDirectory(at: folderStudy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: isoStudy, withIntermediateDirectories: true)

        let mockISO = root.appendingPathComponent("MockStudy.iso")
        if !FileManager.default.fileExists(atPath: mockISO.path) {
            FileManager.default.createFile(atPath: mockISO.path, contents: Data("mock".utf8))
        }

        try writeSyntheticStudy(to: folderStudy, studyName: "Synthetic Folder Study")
        try writeSyntheticStudy(to: isoStudy, studyName: "Synthetic ISO Study")
    }

    static func writeSyntheticStudy(to root: URL, studyName: String) throws {
        let seriesPath = root.appendingPathComponent("SERIES1", isDirectory: true)
        try FileManager.default.createDirectory(at: seriesPath, withIntermediateDirectories: true)

        let imageOnePath = seriesPath.appendingPathComponent("IMAGE0001")
        let imageTwoPath = seriesPath.appendingPathComponent("IMAGE0002")

        try makeSyntheticDICOM(
            instanceNumber: 1,
            seriesDescription: "PA Chest",
            sopInstanceUID: "1.2.826.0.1.3680043.10.543.1",
            pixels: gradientPixels(width: 16, height: 16)
        ).write(to: imageOnePath)

        try makeSyntheticDICOM(
            instanceNumber: 2,
            seriesDescription: "PA Chest",
            sopInstanceUID: "1.2.826.0.1.3680043.10.543.2",
            pixels: checkerboardPixels(width: 16, height: 16)
        ).write(to: imageTwoPath)

        let dicomDirData = try makeSyntheticDICOMDIR(
            rootFileIDs: [
                ["SERIES1", "IMAGE0001"],
                ["SERIES1", "IMAGE0002"]
            ],
            studyName: studyName
        )
        try dicomDirData.write(to: root.appendingPathComponent("DICOMDIR"))
    }

    static func gradientPixels(width: Int, height: Int) -> [UInt16] {
        (0..<(width * height)).map { UInt16(($0 * 32) % 4096) }
    }

    static func checkerboardPixels(width: Int, height: Int) -> [UInt16] {
        (0..<(width * height)).map { index in
            let row = index / width
            let column = index % width
            return ((row + column) % 2 == 0) ? 256 : 3584
        }
    }

    private static func makeSyntheticDICOM(
        instanceNumber: Int,
        seriesDescription: String,
        sopInstanceUID: String,
        pixels: [UInt16]
    ) throws -> Data {
        var data = Data(repeating: 0, count: 128)
        data.append(Data("DICM".utf8))

        data.append(makeExplicitElement(tag: 0x00020000, vr: "UL", value: UInt32(58).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00020010, vr: "UI", value: paddedASCII("1.2.840.10008.1.2.1")))

        data.append(makeExplicitElement(tag: 0x00080016, vr: "UI", value: paddedASCII("1.2.840.10008.5.1.4.1.1.1")))
        data.append(makeExplicitElement(tag: 0x00080018, vr: "UI", value: paddedASCII(sopInstanceUID)))
        data.append(makeExplicitElement(tag: 0x0008103E, vr: "LO", value: paddedASCII(seriesDescription)))
        data.append(makeExplicitElement(tag: 0x00200013, vr: "IS", value: paddedASCII(String(instanceNumber))))
        data.append(makeExplicitElement(tag: 0x00280002, vr: "US", value: UInt16(1).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00280004, vr: "CS", value: paddedASCII("MONOCHROME2")))
        data.append(makeExplicitElement(tag: 0x00280010, vr: "US", value: UInt16(16).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00280011, vr: "US", value: UInt16(16).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00280100, vr: "US", value: UInt16(16).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00280101, vr: "US", value: UInt16(12).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00280103, vr: "US", value: UInt16(0).littleEndianData))

        var pixelBytes = Data()
        for pixel in pixels {
            pixelBytes.append(pixel.littleEndianData)
        }
        data.append(makeExplicitElement(tag: 0x7FE00010, vr: "OW", value: pixelBytes))
        return data
    }

    private static func makeSyntheticDICOMDIR(rootFileIDs: [[String]], studyName: String) throws -> Data {
        var data = Data(repeating: 0, count: 128)
        data.append(Data("DICM".utf8))

        data.append(makeExplicitElement(tag: 0x00020000, vr: "UL", value: UInt32(58).littleEndianData))
        data.append(makeExplicitElement(tag: 0x00020010, vr: "UI", value: paddedASCII("1.2.840.10008.1.2.1")))
        data.append(makeExplicitElement(tag: 0x00041200, vr: "UL", value: UInt32(0).littleEndianData))

        var sequenceValue = Data()
        for fileIDs in rootFileIDs {
            var itemContent = Data()
            itemContent.append(makeExplicitElement(tag: 0x00041430, vr: "CS", value: paddedASCII("IMAGE")))
            itemContent.append(makeExplicitElement(tag: 0x00041500, vr: "CS", value: paddedASCII(fileIDs.joined(separator: "\\"))))
            itemContent.append(makeExplicitElement(tag: 0x00041510, vr: "UI", value: paddedASCII(studyName)))
            sequenceValue.append(sequenceItem(with: itemContent))
        }
        sequenceValue.append(UInt32(0xFFFEE0DD).littleEndianData)
        sequenceValue.append(UInt32(0).littleEndianData)
        data.append(makeExplicitElement(tag: 0x00041220, vr: "SQ", value: sequenceValue))
        return data
    }

    private static func sequenceItem(with content: Data) -> Data {
        var data = Data()
        data.append(UInt32(0xFFFEE000).littleEndianData)
        data.append(UInt32(content.count).littleEndianData)
        data.append(content)
        return data
    }

    private static func makeExplicitElement(tag: UInt32, vr: String, value: Data) -> Data {
        var data = Data()
        data.append(UInt16((tag >> 16) & 0xFFFF).littleEndianData)
        data.append(UInt16(tag & 0xFFFF).littleEndianData)
        data.append(Data(vr.utf8))

        if ["OB", "OD", "OF", "OL", "OV", "OW", "SQ", "UC", "UR", "UT", "UN"].contains(vr) {
            data.append(Data([0, 0]))
            data.append(UInt32(value.count).littleEndianData)
        } else {
            data.append(UInt16(value.count).littleEndianData)
        }

        data.append(value)
        if value.count % 2 != 0 {
            data.append(0)
        }
        return data
    }

    private static func paddedASCII(_ value: String) -> Data {
        var text = value
        if text.count % 2 != 0 {
            text.append(" ")
        }
        return Data(text.utf8)
    }
}

private extension UInt16 {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian) { Data($0) }
    }
}

private extension UInt32 {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian) { Data($0) }
    }
}
