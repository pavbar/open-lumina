import SwiftUI

struct StudyBrowserView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            imageColumn
        } detail: {
            viewerDetail
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
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
            }
        }
        .alert("Unable to Open Study", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        Group {
            if let catalog = viewModel.catalog {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        studySummaryCard(catalog: catalog)
                        seriesRail(catalog: catalog)
                    }
                    .padding(20)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor),
                            Color.accentColor.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                emptyColumn(
                    title: "No study open",
                    subtitle: "Open a local folder or ISO file to start reviewing X-ray studies.",
                    systemImage: "square.stack.3d.up"
                )
            }
        }
    }

    private var imageColumn: some View {
        Group {
            if let series = viewModel.selectedSeries {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionHeader(
                            eyebrow: "Series",
                            title: series.title,
                            subtitle: series.subtitle
                        )

                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(series.images) { image in
                                imageRow(image: image, isSelected: image.id == viewModel.selectedImageID)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .controlBackgroundColor),
                            Color(nsColor: .windowBackgroundColor)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .accessibilityIdentifier("image-list")
            } else {
                emptyColumn(
                    title: "Choose a series",
                    subtitle: "Series stay on the left. Images appear here once you pick one.",
                    systemImage: "square.grid.2x2"
                )
            }
        }
    }

    private var viewerDetail: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.17),
                    Color.black
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
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.04),
                                            Color.white.opacity(0.01)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )

                            ScrollView([.horizontal, .vertical]) {
                                Image(nsImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(
                                        width: geometry.size.width * 0.86 * viewModel.zoomScale,
                                        height: geometry.size.height * 0.88 * viewModel.zoomScale
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(36)
                                    .accessibilityIdentifier("dicom-image-view")
                            }
                        }
                    }

                    viewerFooter
                }
                .padding(24)
            } else {
                emptyViewerState
                    .padding(24)
            }
        }
    }

    private func studySummaryCard(catalog: StudyCatalog) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Study")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(catalog.displayName)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .accessibilityIdentifier("study-title")

            Text(catalog.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 10) {
                statChip(value: "\(catalog.series.count)", label: "Series")
                statChip(value: "\(catalog.imageCount)", label: "Images")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func seriesRail(catalog: StudyCatalog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Series")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(catalog.series) { series in
                    seriesRow(series: series, isSelected: series.id == viewModel.selectedSeriesID)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        )
        .accessibilityIdentifier("series-list")
    }

    private func seriesRow(series: StudySeries, isSelected: Bool) -> some View {
        Button {
            viewModel.selectSeries(series.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(series.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 8)
                    if isSelected {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(series.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.6))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("series-\(series.id)")
    }

    private func imageRow(image: StudyImage, isSelected: Bool) -> some View {
        Button {
            viewModel.selectImage(image.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.black.opacity(0.75))
                    Image(systemName: "photo")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(image.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(image.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.78))
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 10 : 4, y: 4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("image-\(image.id)")
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

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        )
    }

    private func emptyColumn(title: String, subtitle: String, systemImage: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
            .padding(20)
        }
    }
}
