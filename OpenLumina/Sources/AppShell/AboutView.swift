import SwiftUI

struct AboutAppMetadata: Equatable {
    let appName: String
    let version: String
    let build: String

    static func current(bundle: Bundle = .main) -> AboutAppMetadata {
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String)
            ?? "Open Lumina"
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
        let build = (bundle.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String) ?? "1"
        return AboutAppMetadata(appName: appName, version: version, build: build)
    }
}

struct AboutView: View {
    let metadata: AboutAppMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text(metadata.appName)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("about-app-name")

                    Text("Version \(metadata.version) (\(metadata.build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("about-app-version")
                }
            }

            Text("A native Apple-platform viewer for opening local X-ray studies from folders and ISO images.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Created by")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Pavlo Barzdun")
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("about-creator-name")
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 240, alignment: .topLeading)
    }
}
