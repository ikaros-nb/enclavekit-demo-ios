//
//  WalletView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// The vault: where to send SOL, what it holds, the way to the send and
/// guardians screens. A recovery in progress comes first, to cancel.
/// Pull down to refresh.
struct WalletView: View {
    let address: PublicKey
    let explorerURL: URL
    let balance: Lamports?
    let status: Wallet.Status?
    /// How many, `nil` until read.
    let guardians: Int?
    let refresh: () async -> Void
    let cancelRecovery: () async -> Void
    @State private var cancelling = false

    var body: some View {
        Form {
            if case let .active(_, recovery?) = status {
                Section {
                    LabeledContent("New key") {
                        Text(recovery.newKey.description)
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    RecoveryCountdown(opensAt: recovery.opensAt)
                    Button(role: .destructive) {
                        Task {
                            cancelling = true
                            await cancelRecovery()
                            cancelling = false
                        }
                    } label: {
                        HStack {
                            Label("Cancel recovery", systemImage: "xmark.octagon")
                            Spacer()
                            if cancelling { ProgressView() }
                        }
                        // The role reddens the text only.
                        .foregroundStyle(.red)
                    }
                    .disabled(cancelling)
                } header: {
                    Label("Recovery in progress", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("A guardian asked to move this wallet to another device. Not you? Cancel, and it stays on this iPhone. Once the delay is over, the new device can take it at any time.")
                }
            }

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
                    Text("The first action creates the wallet on-chain: its rent is part of that action's fee.")
                }
            }

            Section {
                NavigationLink(value: Screen.send) {
                    Label("Send SOL", systemImage: "paperplane")
                }
                if canManage {
                    NavigationLink(value: Screen.guardians) {
                        LabeledContent {
                            Text(guardiansText)
                        } label: {
                            Label("Guardians", systemImage: "person.2")
                        }
                    }
                }
            } footer: {
                if canManage && guardians == 0 {
                    Text("Without a guardian, losing this iPhone loses the wallet.")
                }
            }
        }
        .navigationTitle("Wallet")
        .refreshable { await refresh() }
    }

    private var statusText: String {
        guard let status else { return "…" }
        return switch status {
        case .notOnChainYet: "Not on-chain yet"
        case .active(_, recovery: .some): "Recovery in progress"
        case .active(attested: false, recovery: nil): "Active"
        case .active(attested: true, recovery: nil): "Active, attested"
        case .recovering: "Moving to this device"
        case .keyReplaced: "Moved to another key"
        }
    }

    /// Only the active key names the guardians: the key that made the
    /// wallet, before its first action.
    private var canManage: Bool {
        switch status {
        case .notOnChainYet, .active: true
        case .recovering, .keyReplaced, nil: false
        }
    }

    private var guardiansText: String {
        guard let guardians else { return "…" }
        return guardians == 0 ? "None" : "\(guardians) of \(Wallet.maxGuardians)"
    }
}

#Preview("New") {
    NavigationStack {
        WalletView(
            address: try! PublicKey(base58: DemoConfig.recipient),
            explorerURL: URL(string: "https://explorer.solana.com/?cluster=devnet")!,
            balance: Lamports(sol: "0.05"),
            status: .notOnChainYet,
            guardians: 0,
            refresh: {},
            cancelRecovery: {}
        )
    }
}
