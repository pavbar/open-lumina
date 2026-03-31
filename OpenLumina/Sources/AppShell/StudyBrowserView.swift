import CoreGraphics
import SwiftUI

struct StudyBrowserView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 310, max: 340)
        } content: {
            imageColumn
                .navigationSplitViewColumnWidth(min: 330, ideal: 380, max: 430)
        } detail: {
            viewerDetail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Open Folder") {
                    viewModel.openFolder()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("open-folder-button")

                Button("Open ISO") {
                    viewModel.openISO()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-iso-button")

                Button("Close") {
                    viewModel.closeStudy()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.hasOpenStudy)
                .accessibilityIdentifier("close-study-button")

                Button("Export Image") {
                    exportSelectedImage()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canExportSelectedImage)
                .accessibilityIdentifier("export-image-button")
            }
        }
        .alert(activeAlertTitle, isPresented: Binding(
            get: { activeAlertMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                    viewModel.exportErrorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
                viewModel.exportErrorMessage = nil
            }
        } message: {
            Text(activeAlertMessage ?? "Unknown error")
        }
    }

    private var activeAlertTitle: String {
        viewModel.exportErrorMessage != nil ? "Unable to Export Image" : "Unable to Open Study"
    }

    private var activeAlertMessage: String? {
        viewModel.exportErrorMessage ?? viewModel.errorMessage
    }

    private var sidebar: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if let catalog = viewModel.catalog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        studyHeader(catalog: catalog)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Series")
                                .font(.headline)
                            ForEach(catalog.series) { series in
                                seriesRow(series: series, isSelected: series.id == viewModel.selectedSeriesID)
                            }
                        }
                        .accessibilityIdentifier("series-list")
                    }
                    .padding(18)
                }
            } else {
                emptyState(
                    title: "No study open",
                    subtitle: "Open a local folder or ISO file to browse X-ray studies.",
                    systemImage: "square.stack.3d.up"
                )
                .padding(20)
            }
        }
    }

    private var imageColumn: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
                .ignoresSafeArea()

            if let series = viewModel.selectedSeries {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Series")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(series.title)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                            Text(series.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(series.images) { image in
                                imageRow(image: image, isSelected: image.id == viewModel.selectedImageID)
                            }
                        }
                    }
                    .padding(18)
                }
                .accessibilityIdentifier("image-list")
            } else {
                emptyState(
                    title: "Choose a series",
                    subtitle: "Pick a series on the left to see its images here.",
                    systemImage: "square.grid.2x2"
                )
                .padding(20)
            }
        }
    }

    private var viewerDetail: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.15),
                    Color(red: 0.03, green: 0.03, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let image = viewModel.renderedImage {
                VStack(spacing: 18) {
                    viewerHeader

                    GeometryReader { geometry in
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )

                            ScrollView([.horizontal, .vertical]) {
                                Image(decorative: image, scale: 1.0)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(
                                        width: geometry.size.width * 0.84 * viewModel.zoomScale,
                                        height: geometry.size.height * 0.88 * viewModel.zoomScale
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(32)
                                    .accessibilityIdentifier("dicom-image-view")
                            }
                        }
                    }

                    viewerFooter
                }
                .padding(22)
            } else {
                emptyViewerState
                    .padding(22)
            }
        }
    }

    private func studyHeader(catalog: StudyCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(catalog.displayName)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .accessibilityIdentifier("study-title")

            Text(catalog.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(catalog.series.count) series", systemImage: "square.stack.3d.down.right")
                Label("\(catalog.imageCount) images", systemImage: "photo.on.rectangle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func seriesRow(series: StudySeries, isSelected: Bool) -> some View {
        Button {
            viewModel.selectSeries(series.id)
        } label: {
            HStack(spacing: 12) {
                previewTile(image: viewModel.previewImage(forSeriesID: series.id), placeholder: "square.stack.3d.down.right")
                    .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 4) {
                    Text(series.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(series.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.7))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("series-\(series.id)")
    }

    private func imageRow(image: StudyImage, isSelected: Bool) -> some View {
        Button {
            viewModel.selectImage(image.id)
        } label: {
            HStack(spacing: 12) {
                previewTile(image: viewModel.previewImage(forImageID: image.id), placeholder: "photo")
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text(image.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(image.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.74))
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 10 : 4, y: 4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("image-\(image.id)")
    }

    private func previewTile(image: CGImage?, placeholder: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.85))

            if let image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: placeholder)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var viewerHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.selectedImage?.displayName ?? "Viewer")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("viewer-image-title")

                Text(viewModel.selectedImage?.subtitle ?? "Select a study image to inspect.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                if let series = viewModel.selectedSeries {
                    Label(series.title, systemImage: "square.stack.3d.down.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Export") {
                    exportSelectedImage()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(!viewModel.canExportSelectedImage)
                .accessibilityIdentifier("viewer-export-button")

                Button("Previous") {
                    viewModel.selectPreviousImage()
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(!viewModel.canSelectPreviousImage)
                .accessibilityIdentifier("previous-image-button")

                Button("Next") {
                    viewModel.selectNextImage()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(!viewModel.canSelectNextImage)
                .accessibilityIdentifier("next-image-button")
            }
        }
    }

    private var viewerFooter: some View {
        HStack(spacing: 14) {
            Text("Zoom")
                .foregroundStyle(.white.opacity(0.75))

            Slider(
                value: Binding(
                    get: { viewModel.zoomScale },
                    set: { viewModel.updateZoom($0) }
                ),
                in: 0.25...4.0
            )
            .tint(.white)
            .accessibilityIdentifier("zoom-slider")

            Text("\(Int(viewModel.zoomScale * 100))%")
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 48, alignment: .trailing)

            Button("Fit") {
                viewModel.resetZoom()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var emptyViewerState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Text("Viewer ready")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(viewModel.errorMessage ?? viewModel.statusMessage)
                .font(.body)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func emptyState(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func exportSelectedImage() {
        _ = try? viewModel.exportSelectedImage()
    }
}
