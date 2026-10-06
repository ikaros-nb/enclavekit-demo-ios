//
//  RecoverView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// A new iPhone takes over the wallet of a lost one, in two codes: a
/// guardian scans this iPhone's key and proposes it, then shows the wallet
/// ID for this iPhone to scan.
struct RecoverView: View {
    let deviceKey: DeviceKey
    /// This device's own: not the one to recover.
    let walletID: Wallet.ID
    let recover: (Wallet.ID) async -> Void
    @State private var scanning = false
    @State private var scanned: Wallet.ID?
    @State private var recovering = false

    var body: some View {
        Form {
            Section {
                QRCode(deviceKey.description)
                    .listRowInsets(EdgeInsets())
                // To compare with the guardian's consent sheet.
                Text(deviceKey.description)
                    .font(.footnote.monospaced())
                    .typesettingLanguage(.address)
                    .textSelection(.enabled)
            } header: {
                Text("1. Show this key to a guardian")
            } footer: {
                Text("A guardian of the lost wallet scans it, then approves the proposal on their iPhone.")
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
                Text("The guardian's iPhone shows it once the key is proposed. This iPhone then waits for the delay, and confirms.")
            }
        }
        .navigationTitle("Recover a wallet")
        // A failure's alert waits for this sheet to be gone.
        .sheet(isPresented: $scanning, onDismiss: recoverScanned) {
            ScanSheet(title: "Recover a wallet", prompt: "Scan the wallet ID the guardian's iPhone shows.", read: lostWallet) {
                scanned = $0
            }
        }
    }

    private func lostWallet(_ text: String) throws -> Wallet.ID {
        let id = try Wallet.ID(text)
        guard id != walletID else { throw ScanRefusal("This is this iPhone's own wallet: scan the one the guardian shows.") }
        return id
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
            walletID: try! Wallet.ID("enclavekit:wallet:\(DemoConfig.recipient)"),
            recover: { _ in }
        )
    }
}
