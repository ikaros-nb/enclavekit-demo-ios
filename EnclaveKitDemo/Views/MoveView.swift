//
//  MoveView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 07/10/2026.
//

import EnclaveKit
import SwiftUI

/// The wallet to a new iPhone while this one still signs: no guardian, no
/// delay. The new iPhone shows its key, this one scans it and approves the
/// move, then shows the wallet ID for the new one to scan.
struct MoveView: View {
    let walletID: Wallet.ID
    /// This device's: the wallet's key already.
    let deviceKey: DeviceKey
    /// `nil` until read: a guardian is no new iPhone.
    let guardians: [DeviceKey]?
    /// Confirmed: what is left is the wallet ID, for the new iPhone.
    let moved: Bool
    /// Moving ends it too.
    let recoveryPending: Bool
    /// The new iPhone's key, for the consent sheet.
    let review: (DeviceKey) async -> Void
    @State private var scanning = false
    @State private var scanned: DeviceKey?
    @State private var reviewing = false

    var body: some View {
        Form {
            if moved {
                Section {
                    QRCode(walletID.description)
                        .listRowInsets(EdgeInsets())
                    Text(walletID.description)
                        .font(.footnote.monospaced())
                        .typesettingLanguage(.address)
                        .textSelection(.enabled)
                } header: {
                    Label("Moved: show the wallet ID", systemImage: "checkmark.circle.fill")
                } footer: {
                    Text("The new iPhone scans it in Recover a wallet, and signs for the wallet from then on. This iPhone no longer does.")
                }
            } else {
                Section {
                    Text("Open the demo there, create its wallet if it has none, then open Recover a wallet: it shows the iPhone's key.")
                } header: {
                    Text("1. On the new iPhone")
                } footer: {
                    Text("An iPhone signs for one wallet at a time: the new one must not sign for its own already.")
                }

                Section {
                    Button {
                        scanning = true
                    } label: {
                        HStack {
                            Label("Scan the new iPhone's key", systemImage: "qrcode.viewfinder")
                            Spacer()
                            if reviewing { ProgressView() }
                        }
                    }
                    .disabled(guardians == nil || reviewing)
                } header: {
                    Text("2. Move the wallet")
                } footer: {
                    Text(footer)
                }
            }
        }
        .navigationTitle("Move to another iPhone")
        .navigationBarTitleDisplayMode(.inline)
        // The consent sheet waits for this one to be gone.
        .sheet(isPresented: $scanning, onDismiss: reviewScanned) {
            ScanSheet(title: "Move wallet", prompt: "Scan the key the new iPhone shows in Recover a wallet.", read: newKey) {
                scanned = $0
            }
        }
    }

    private var footer: String {
        let about = "You approve the move next. It takes effect at once: the new iPhone signs for the wallet, this one no longer does. The address, the funds and the guardians stay."
        return recoveryPending ? about + " It also ends the recovery in progress." : about
    }

    /// Neither this iPhone's key nor a guardian's: the wallet names them
    /// already.
    private func newKey(_ text: String) throws -> DeviceKey {
        let key = try DeviceKey(text)
        guard key != deviceKey else { throw ScanRefusal("This is this iPhone's key: scan the one the new iPhone shows.") }
        guard guardians?.contains(key) != true else {
            throw ScanRefusal("This device guards the wallet: remove it from the guardians first, then move the wallet to it.")
        }
        return key
    }

    private func reviewScanned() {
        guard let scanned else { return }
        self.scanned = nil
        Task {
            reviewing = true
            await review(scanned)
            reviewing = false
        }
    }
}

#Preview("Before") {
    NavigationStack {
        MoveView(
            walletID: try! Wallet.ID("enclavekit:wallet:FAnBvyFqTsuE8HTbq9yCDS4fuWyHnvH8CH5Vi5EqKcNQ"),
            deviceKey: try! DeviceKey("02b215cb41f4972504ed49327411f0784a5378476f42a07d6f4cd21d0261c3e9d0"),
            guardians: [],
            moved: false,
            recoveryPending: false,
            review: { _ in }
        )
    }
}

#Preview("Moved") {
    NavigationStack {
        MoveView(
            walletID: try! Wallet.ID("enclavekit:wallet:FAnBvyFqTsuE8HTbq9yCDS4fuWyHnvH8CH5Vi5EqKcNQ"),
            deviceKey: try! DeviceKey("02b215cb41f4972504ed49327411f0784a5378476f42a07d6f4cd21d0261c3e9d0"),
            guardians: [],
            moved: true,
            recoveryPending: false,
            review: { _ in }
        )
    }
}
