import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct AssetImageView: View {

    @Bindable var asset: FixedAsset
    @Environment(\.modelContext) private var modelContext

    @State private var showingImporter = false
    @State private var errorMessage = ""
    @State private var showingError = false

    var body: some View {

            GeometryReader { geometry in

                ZStack {

                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.05))

                    if let data = asset.imageData,
                       let image = NSImage(data: data) {

                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()

                    } else {

                        VStack(spacing: 12) {

                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))

                            Text("Upload an image")
                                .font(.headline)

                            Text("Click to select a photo")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 16)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.secondary.opacity(0.35),
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: [6, 5]
                            )
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    showingImporter = true
                } label: {
                    Label(
                        asset.imageData == nil ? "Upload Photo" : "Change Photo",
                        systemImage: "photo.on.rectangle"
                    )
                }

                if asset.imageData != nil {
                    Button(role: .destructive) {
                        let previousImage = asset.imageData
                        asset.imageData = nil

                        do {
                            try modelContext.save()
                        } catch {
                            asset.imageData = previousImage
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image]
        ) { result in

            do {
                let url = try result.get()

                let access = url.startAccessingSecurityScopedResource()

                defer {
                    if access {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)

                guard NSImage(data: data) != nil else {
                    throw AssetImageError.invalidImage
                }

                guard data.count <= 10_000_000 else {
                    throw AssetImageError.imageTooLarge
                }

                let previousImage = asset.imageData
                asset.imageData = data

                do {
                    try modelContext.save()
                } catch {
                    asset.imageData = previousImage
                    throw error
                }

            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .alert(
            "Image Upload Failed",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

private enum AssetImageError: LocalizedError {

    case invalidImage
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected file is not a supported image."
        case .imageTooLarge:
            return "Please select an image smaller than 10 MB."
        }
    }
}

