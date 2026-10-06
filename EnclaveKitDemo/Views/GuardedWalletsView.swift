//
//  GuardedWalletsView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// The guardian's side: the wallets this device guards, and the two codes
/// that make it a guardian. The owner scans this device's key; this device
/// scans the owner's wallet ID.
struct GuardedWalletsView: View {
    struct Row: Identifiable {
        let id: Wallet.ID
        let address: PublicKey
        /// `nil` until read.
        let status: GuardedWallet.Status?
    }

    let rows: [Row]
    /// This device's own: never one it guards.
    let walletID: Wallet.ID
    let deviceKey: DeviceKey
    let refresh: () async -> Void
    let keep: (Wallet.ID) async -> Void
    @State private var showingKey = false
    @State private var scanning = false
    @State private var scanned: Wallet.ID?

    var body: some View {
        Form {
            Section {
                if rows.isEmpty {
                    Text("No wallet yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { row in
                    NavigationLink(value: Screen.guardedWallet(row.id)) {
                        VStack(alignment: .leading) {
                            // Its vault, as its owner's screen shows it.
                            Text(row.address.base58)
                                .font(.footnote.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(row.status?.text ?? "…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Wallets whose owner named this iPhone as guardian. If they lose their iPhone, you move the wallet to their new one.")
            }

            Section {
                Button("Show device key", systemImage: "qrcode") { showingKey = true }
                Button("Guard a wallet", systemImage: "qrcode.viewfinder") { scanning = true }
            } footer: {
                Text("The owner scans this iPhone's key in their Guardians screen, then shows their wallet ID for you to scan, once.")
            }
        }
        .navigationTitle("Guarding")
        .refreshable { await refresh() }
        .sheet(isPresented: $showingKey) {
            QRCodeSheet(
                title: "Device key",
                text: deviceKey.description,
                caption: "The wallet's owner scans it to name this iPhone as guardian."
            )
        }
        // A failure's alert waits for this sheet to be gone.
        .sheet(isPresented: $scanning, onDismiss: keepScanned) {
            ScanSheet(title: "Guard a wallet", prompt: "Scan the wallet ID its owner's iPhone shows.", read: newWallet) {
                scanned = $0
            }
        }
    }

    /// A wallet ID, neither this device's own nor one it guards already.
    private func newWallet(_ text: String) throws -> Wallet.ID {
        let id = try Wallet.ID(text)
        guard id != walletID else { throw ScanRefusal("This is this iPhone's own wallet: a guardian is another device.") }
        guard !rows.contains(where: { $0.id == id }) else { throw ScanRefusal("This iPhone guards this wallet already.") }
        return id
    }

    private func keepScanned() {
        guard let scanned else { return }
        self.scanned = nil
        Task { await keep(scanned) }
    }
}

extension GuardedWallet.Status {
    var text: String {
        switch self {
        case .guarding(recovery: nil): "Guarding"
        case .guarding(recovery: .some): "Recovery in progress"
        case .notGuarding: "Not named as guardian"
        }
    }
}

#Preview {
    NavigationStack {
        GuardedWalletsView(
            rows: [
                .init(
                    id: try! Wallet.ID("enclavekit:wallet:FAnBvyFqTsuE8HTbq9yCDS4fuWyHnvH8CH5Vi5EqKcNQ"),
                    address: try! PublicKey(base58: DemoConfig.recipient),
                    status: .guarding(recovery: nil)
                ),
            ],
            walletID: try! Wallet.ID("enclavekit:wallet:\(DemoConfig.recipient)"),
            deviceKey: try! DeviceKey("02e0552f7c3d1c0b59412b9211256544acbec3694d3240bd91dca7f2d2068e16ca"),
            refresh: {},
            keep: { _ in }
        )
    }
}
