//
//  WalletView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// The vault: where to send SOL, what it holds, the way to the send screen.
/// Pull down to refresh.
struct WalletView: View {
    let address: PublicKey
    let explorerURL: URL
    let balance: Lamports?
    let status: Wallet.Status?
    let refresh: () async -> Void
    let send: () -> Void

    var body: some View {
        Form {
            Section {
                Text(address.base58)
                    .font(.footnote.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                Button("Copy address", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = address.base58
                }
                Link(destination: explorerURL) {
                    Label("View in Explorer", systemImage: "safari")
                }
            } header: {
                Text("Address")
            } footer: {
                Text("Receives SOL right away, before the first send.")
            }

            Section {
                LabeledContent("Balance", value: balance?.formatted ?? "…")
                LabeledContent("Status", value: statusText)
            } footer: {
                if status == .notOnChainYet {
                    Text("The first send creates the wallet on-chain: its rent is part of that send's fee.")
                }
            }

            Section {
                Button("Send SOL", systemImage: "paperplane", action: send)
            }
        }
        .navigationTitle("Wallet")
        .refreshable { await refresh() }
    }

    private var statusText: String {
        guard let status else { return "…" }
        return switch status {
        case .notOnChainYet: "Not on-chain yet"
        case .active(attested: false): "Active"
        case .active(attested: true): "Active, attested"
        case .keyReplaced: "Moved to another key"
        }
    }
}

#Preview {
    NavigationStack {
        WalletView(
            address: try! PublicKey(base58: DemoConfig.recipient),
            explorerURL: URL(string: "https://explorer.solana.com/?cluster=devnet")!,
            balance: Lamports(sol: "0.05"),
            status: .notOnChainYet,
            refresh: {},
            send: {}
        )
    }
}
