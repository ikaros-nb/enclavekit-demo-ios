//
//  RecoverView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// A new iPhone takes over a wallet, in two codes: the iPhone that signs for
/// it, or a guardian if that one is lost, scans this iPhone's key, then
/// shows the wallet ID for this iPhone to scan. This iPhone's own wallet,
/// moved away, comes back the same way.
struct RecoverView: View {
    let deviceKey: DeviceKey
    let recover: (Wallet.ID) async -> Void
    @State private var scanning = false
    @State private var scanned: Wallet.ID?
    @State private var recovering = false

    var body: some View {
        Form {
            Section {
                QRCode(deviceKey.description)
                    .listRowInsets(EdgeInsets())
                // To compare with the other iPhone's consent sheet.
                Text(deviceKey.description)
                    .font(.footnote.monospaced())
                    .typesettingLanguage(.address)
                    .textSelection(.enabled)
            } header: {
                Text("1. Show this key")
            } footer: {
                Text("To the iPhone that signs for the wallet: it moves the wallet here at once. If that iPhone is lost, to one of the wallet's guardians: it proposes this key.")
            }

            Section {
                Button {
                    scanning = true
                } label: {
                    HStack {
                        Label("Scan wallet ID", systemImage: "qrcode.viewfinder")
                        Spacer()
                        if recovering { ProgressView() }
                    }
                }
                .disabled(recovering)
            } header: {
                Text("2. Scan the wallet ID")
            } footer: {
                Text("The other iPhone shows it once done. After a move, this iPhone signs at once; after a guardian's proposal, it waits for the delay, then confirms.")
            }
        }
        .navigationTitle("Recover a wallet")
        // A failure's alert waits for this sheet to be gone.
        .sheet(isPresented: $scanning, onDismiss: recoverScanned) {
            ScanSheet(title: "Recover a wallet", prompt: "Scan the wallet ID the other iPhone shows.", read: { try Wallet.ID($0) }) {
                scanned = $0
            }
        }
    }

    private func recoverScanned() {
        guard let scanned else { return }
        self.scanned = nil
        Task {
            recovering = true
            await recover(scanned)
            recovering = false
        }
    }
}

#Preview {
    NavigationStack {
        RecoverView(
            deviceKey: try! DeviceKey("02b215cb41f4972504ed49327411f0784a5378476f42a07d6f4cd21d0261c3e9d0"),
            recover: { _ in }
        )
    }
}
