import Foundation

enum StudyInput: Equatable {
    case folder(URL)
    case iso(URL)

    var diagnosticLabel: String {
        switch self {
        case .folder:
            return "folder"
        case .iso:
            return "iso"
        }
    }
}

enum StudySource: Equatable {
    case folder(URL)
    case mountedISO(imageURL: URL, mountURL: URL)

    var rootURL: URL {
        switch self {
        case .folder(let url):
            return url
        case .mountedISO(_, let mountURL):
            return mountURL
        }
    }
}

struct StudySession {
    let source: StudySource
    let catalog: StudyCatalog
    let cleanup: () -> Void
}

protocol ISOImporting {
    func mountISO(at url: URL) throws -> DisposableStudyMount
}

struct DisposableStudyMount {
    let rootURL: URL
    let cleanup: () -> Void
}

enum StudyImportError: LocalizedError {
    case invalidISO(URL)
    case mountFailed(String)
    case cleanupFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidISO(let url):
            return "The selected file is not a supported ISO image: \(url.lastPathComponent)"
        case .mountFailed(let output):
            return "Unable to mount the ISO image. \(output)"
        case .cleanupFailed(let output):
            return "The ISO workspace could not be cleaned up. \(output)"
        }
    }
}

struct ISOStudyImporter: ISOImporting {
    let diagnosticsStore: DiagnosticLogStore

    func mountISO(at url: URL) throws -> DisposableStudyMount {
        guard url.pathExtension.lowercased() == "iso" else {
            diagnosticsStore.record("iso_mount_rejected", details: ["reason": "invalid_extension"])
            throw StudyImportError.invalidISO(url)
        }

        let mountURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lumina-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mountURL, withIntermediateDirectories: true)
        diagnosticsStore.record("iso_mount_started")

        let attachResult = Shell.run(
            "/usr/bin/hdiutil",
            arguments: [
                "attach",
                "-readonly",
                "-nobrowse",
                "-mountpoint",
                mountURL.path,
                url.path
            ]
        )

        guard attachResult.exitCode == 0 else {
            try? FileManager.default.removeItem(at: mountURL)
            diagnosticsStore.record(
                "iso_mount_failed",
                details: ["reason": attachResult.diagnosticReason]
            )
            throw StudyImportError.mountFailed(attachResult.stderr.isEmpty ? attachResult.stdout : attachResult.stderr)
        }

        diagnosticsStore.record("iso_mount_succeeded")

        return DisposableStudyMount(rootURL: mountURL) {
            diagnosticsStore.record("iso_detach_started")
            let detachResult = Shell.run(
                "/usr/bin/hdiutil",
                arguments: ["detach", mountURL.path]
            )
            if detachResult.exitCode != 0 {
                diagnosticsStore.record(
                    "iso_detach_failed",
                    details: ["reason": detachResult.diagnosticReason]
                )
            } else {
                diagnosticsStore.record("iso_detach_succeeded")
            }
            try? FileManager.default.removeItem(at: mountURL)
        }
    }
}

struct MockISOStudyImporter: ISOImporting {
    let root: URL

    func mountISO(at url: URL) throws -> DisposableStudyMount {
        guard url.lastPathComponent == "MockStudy.iso" else {
            throw StudyImportError.invalidISO(url)
        }
        let mountURL = root.appendingPathComponent("MountedISO", isDirectory: true)
        return DisposableStudyMount(rootURL: mountURL) { }
    }
}

struct ShellResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum Shell {
    static func run(_ executable: String, arguments: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ShellResult(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        return ShellResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }
}

private extension ShellResult {
    var diagnosticReason: String {
        let output = (stderr.isEmpty ? stdout : stderr).lowercased()

        if output.contains("resource busy") {
            return "resource_busy"
        }
        if output.contains("no such file") {
            return "file_missing"
        }
        if output.contains("not permitted") || output.contains("permission") {
            return "permission_denied"
        }
        if output.contains("timed out") {
            return "timeout"
        }

        return exitCode == 0 ? "ok" : "command_failed_\(exitCode)"
    }
}
