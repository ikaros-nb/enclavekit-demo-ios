//
//  QRCodeSheet.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

/// A text for another device's camera: its QR code, then the text itself,
/// to compare by eye or to copy toward a Mac.
struct QRCodeSheet: View {
    let title: String
    let text: String
    /// Who scans it, and what for.
    let caption: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    QRCode(text)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text(caption)
                }

                Section {
                    Text(text)
                        .font(.footnote.monospaced())
                        .typesettingLanguage(.address)
                        .textSelection(.enabled)
                    Button("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = text
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Black on white whatever the appearance, inside the quiet zone scanners
/// look for. Sharp at any size: one pixel per module, scaled without
/// smoothing.
struct QRCode: View {
    private static let context = CIContext()
    private let image: CGImage?

    init(_ text: String) {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        image = filter.outputImage.flatMap { Self.context.createCGImage($0, from: $0.extent) }
    }

    var body: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(32)
                .background(.white)
        }
    }
}

#Preview {
    QRCodeSheet(
        title: "Wallet ID",
        text: "enclavekit:wallet:FAnBvyFqTsuE8HTbq9yCDS4fuWyHnvH8CH5Vi5EqKcNQ",
        caption: "Each guardian scans it once, to find this wallet the day you need them."
    )
}
