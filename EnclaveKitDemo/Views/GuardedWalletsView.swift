//
//  GuardedWalletsView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// The guardian's side: the wallets that name this device, read on-chain,
/// and the one code that makes it a guardian. The owner scans this
/// device's key; their wallet then shows here on its own.
struct GuardedWalletsView: View {
    struct Row: Identifiable {
        let id: Wallet.ID
        let address: PublicKey
        /// `nil` until read.
        let status: GuardedWallet.Status?
    }

    let rows: [Row]
    let deviceKey: DeviceKey
    /// Why the last read failed: the screen tries again all the same.
    let failure: String?
    let refresh: () async -> Void
    /// One read of the chain, every few seconds.
    let look: () async -> Void
    @State private var showingKey = false

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
                if let failure {
                    Text("\(failure) Trying again.")
                        .foregroundStyle(.red)
                } else {
                    Text("Wallets whose owner named this iPhone as guardian. If they lose their iPhone, you move the wallet to their new one.")
                }
            }

            Section {
                Button("Show device key", systemImage: "qrcode") { showingKey = true }
            } footer: {
                Text("The owner scans this iPhone's key in their Guardians screen. Once they approve, their wallet shows here.")
            }
        }
        .navigationTitle("Guarding")
        .refreshable { await refresh() }
        .polling(look)
        .sheet(isPresented: $showingKey) {
            QRCodeSheet(
                title: "Device key",
                text: deviceKey.description,
                caption: "The wallet's owner scans it to name this iPhone as guardian."
            )
        }
    }
}

extension GuardedWallet.Status {
    var text: String {
        switch self {
        case .guarding(recovery: nil): "Guarding"
        case .guarding(recovery: .some): "Recovery in progress"
        case .notGuarding: "No longer named as guardian"
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
            deviceKey: try! DeviceKey("02e0552f7c3d1c0b59412b9211256544acbec3694d3240bd91dca7f2d2068e16ca"),
            failure: nil,
            refresh: {},
            look: {}
        )
    }
}
