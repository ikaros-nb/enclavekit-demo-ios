//
//  WalletView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// The vault: where to send SOL, what it holds, the way to the send and
/// guardians screens, then what this iPhone does for other wallets, how it
/// hands its own to another iPhone and how it starts over. A recovery comes
/// first: to cancel on the owner's iPhone, to wait for on the new one, which
/// confirms on its own. Then a wallet without a guardian says so, on top.
/// Pull down to refresh.
struct WalletView: View {
    let address: PublicKey
    let explorerURL: URL
    let balance: Lamports?
    let status: Wallet.Status?
    /// How many, `nil` until read.
    let guardians: Int?
    /// How many wallets this iPhone guards.
    let guarding: Int
    /// A recovery toward this iPhone being confirmed, on its own once the
    /// delay is over, or by the button after a failure.
    let confirming: Bool
    let refresh: () async -> Void
    let cancelRecovery: () async -> Void
    let confirmRecovery: () async -> Void
    let deleteDeviceKey: () -> Void
    @State private var cancelling = false
    @State private var confirmingDeletion = false

    var body: some View {
        Form {
            if case let .recovering(recovery) = status {
                Section {
                    RecoveryCountdown(opensAt: recovery.opensAt)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Button {
                            Task { await confirmRecovery() }
                        } label: {
                            HStack {
                                Label("Confirm recovery", systemImage: "checkmark.shield")
                                Spacer()
                                // Sending, past the delay; waiting, before.
                                if confirming && context.date >= recovery.opensAt { ProgressView() }
                            }
                        }
                        .disabled(context.date < recovery.opensAt || confirming)
                    }
                } header: {
                    Label("Recovery to this iPhone", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text("A guardian proposed this iPhone's key. Once the delay is over, this iPhone confirms on its own: the wallet's key becomes this iPhone's. Nothing to approve, the relayer pays the fee. The button is there if that fails. Until then, the old iPhone can still cancel.")
                }
            }

            if case let .active(recovery?) = status {
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

            if canSign && guardians == 0 {
                Section {
                    NavigationLink(value: Screen.guardians) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No guardian")
                                    .font(.headline)
                                Text("Losing this iPhone loses the wallet. Add a second iPhone or iPad.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
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
                if status == .keyReplaced {
                    Text("Another key signs for this wallet now. To bring it back, open Recover a wallet; to start over, delete this iPhone's key.")
                }
            }

            if canSign {
                Section {
                    NavigationLink(value: Screen.send) {
                        Label("Send SOL", systemImage: "paperplane")
                    }
                    NavigationLink(value: Screen.guardians) {
                        LabeledContent {
                            Text(guardiansText)
                        } label: {
                            Label("Guardians", systemImage: "person.2")
                        }
                    }
                }
            }

            Section {
                NavigationLink(value: Screen.guarding) {
                    LabeledContent {
                        Text(guarding == 0 ? "None" : "\(guarding)")
                    } label: {
                        Label("Guarding", systemImage: "shield.lefthalf.filled")
                    }
                }
                if canMove {
                    NavigationLink(value: Screen.move) {
                        Label("Move to another iPhone", systemImage: "iphone.and.arrow.right.outward")
                    }
                }
                if canRecover {
                    NavigationLink(value: Screen.recover) {
                        Label("Recover a wallet", systemImage: "lifepreserver")
                    }
                }
                if canSign {
                    NavigationLink(value: Screen.close) {
                        Label("Close wallet", systemImage: "xmark.bin")
                    }
                }
                Button(role: .destructive) {
                    confirmingDeletion = true
                } label: {
                    Label("Delete device key", systemImage: "key.slash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("This iPhone")
            } footer: {
                Text(canSign ? "Closing the wallet is how the demo starts over; deleting the key, how it loses this iPhone." : "Deleting the key is how the demo loses this iPhone.")
            }
        }
        .navigationTitle("Wallet")
        .refreshable { await refresh() }
        .confirmationDialog("Delete this iPhone's key?", isPresented: $confirmingDeletion, titleVisibility: .visible) {
            Button("Delete key", role: .destructive, action: deleteDeviceKey)
        } message: {
            Text(deletionWarning)
        }
    }

    private var statusText: String {
        guard let status else { return "…" }
        return switch status {
        case .notOnChainYet: "Not on-chain yet"
        case .active(recovery: .some): "Recovery in progress"
        case .active(recovery: nil): "Active"
        case .recovering: "Moving to this iPhone"
        case .keyReplaced: "Moved to another key"
        }
    }

    /// Only the active key acts: the key that made the wallet, before its
    /// first action.
    private var canSign: Bool {
        switch status {
        case .notOnChainYet, .active: true
        case .recovering, .keyReplaced, nil: false
        }
    }

    /// Once on-chain: before, the wallet has no key to move.
    private var canMove: Bool {
        if case .active = status { true } else { false }
    }

    /// A wallet this iPhone signs for, or recovers, stays its own.
    private var canRecover: Bool {
        switch status {
        case .notOnChainYet, .keyReplaced: true
        case .active, .recovering, nil: false
        }
    }

    private var guardiansText: String {
        guard let guardians else { return "…" }
        return guardians == 0 ? "None" : "\(guardians) of \(Wallet.maxGuardians)"
    }

    private var deletionWarning: String {
        let about = "The wallet stays on-chain with what it holds, but this iPhone can no longer sign for it: only a guardian can move it to a new iPhone. The wallets this iPhone guards lose it as guardian."
        return canSign && guardians == 0 ? about + " This wallet has no guardian: what it holds is lost for good." : about
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
            guarding: 0,
            confirming: false,
            refresh: {},
            cancelRecovery: {},
            confirmRecovery: {},
            deleteDeviceKey: {}
        )
    }
}
