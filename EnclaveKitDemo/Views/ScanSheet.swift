//
//  ScanSheet.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// The camera, until it sees a QR code `read` accepts; or the text pasted
/// below it, for a code shown on a Mac. A code `read` refuses keeps the
/// sheet open, the reason under the field.
struct ScanSheet<Value>: View {
    let title: String
    /// What to point the camera at.
    let prompt: String
    let read: (String) throws -> Value
    let found: (Value) -> Void
    @Environment(\.dismiss) private var dismiss
    /// `nil` until the user answers the camera prompt, the first time.
    @State private var camera: Bool?
    @State private var pasted = ""
    @State private var refusal: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Group {
                        switch camera {
                        case nil:
                            ProgressView()
                        case true?:
                            QRScanner(scanned: accept)
                        case false?:
                            ContentUnavailableView(
                                "No camera",
                                systemImage: "video.slash",
                                description: Text("Allow the camera in Settings, or paste the text below.")
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text(prompt)
                }

                Section {
                    TextField("Or paste the text", text: $pasted)
                        .font(.footnote.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: pasted) {
                            if pasted.isEmpty { refusal = nil } else { accept(pasted) }
                        }
                } footer: {
                    if let refusal {
                        Text(refusal).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // The simulator has no scanner. Elsewhere this asks once.
                guard DataScannerViewController.isSupported else {
                    camera = false
                    return
                }
                camera = await AVCaptureDevice.requestAccess(for: .video)
            }
        }
    }

    private func accept(_ text: String) {
        do {
            found(try read(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            dismiss()
        } catch {
            refusal = error.localizedDescription
        }
    }
}

/// Why a code that reads fine is still not the one wanted.
struct ScanRefusal: LocalizedError {
    let errorDescription: String?

    init(_ reason: String) {
        errorDescription = reason
    }
}

/// VisionKit's live scanner, QR codes only: `scanned` gets each new code's
/// text.
private struct QRScanner: UIViewControllerRepresentable {
    let scanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.scanned = scanned
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scanned: scanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var scanned: (String) -> Void

        init(scanned: @escaping (String) -> Void) {
            self.scanned = scanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case let .barcode(code) in addedItems {
                if let text = code.payloadStringValue { scanned(text) }
            }
        }
    }
}

#Preview {
    ScanSheet(title: "Add guardian", prompt: "Scan the key your guardian's device shows.", read: { $0 }, found: { _ in })
}
