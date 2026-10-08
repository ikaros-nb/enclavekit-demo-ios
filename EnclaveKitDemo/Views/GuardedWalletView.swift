//
//  GuardedWalletView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// One wallet this device guards. The day its owner loses their iPhone:
/// propose the key their new one shows, which then finds the wallet on its
/// own. A wallet this iPhone does not mean to guard: forget it.
struct GuardedWalletView: View {
    let address: PublicKey
    let explorerURL: URL
    /// `nil` until read.
    let status: GuardedWallet.Status?
    /// This device's: never the new one.
    let deviceKey: DeviceKey
    let refresh: () async -> Void
    /// The new device's key, for the consent sheet.
    let review: (DeviceKey) async -> Void
    /// Off this iPhone's list, back to it.
    let forget: () -> Void
    @State private var scanning = false
    @State private var scanned: DeviceKey?
    @State private var reviewing = false
    @State private var confirmingForget = false

    var body: some View {
        Form {
            if case let .guarding(recovery?) = status {
                Section {
                    LabeledContent("New key") {
                        Text(recovery.newKey.description)
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    RecoveryCountdown(opensAt: recovery.opensAt)
                } header: {
                    Label("Recovery in progress", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text("The new iPhone finds the wallet on its own, then confirms once the delay is over. Until then, the owner's old iPhone can still cancel.")
                }
            }

            Section {
                Text(address.base58)
                    .font(.footnote.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                Link(destination: explorerURL) {
                    Label("View in Explorer", systemImage: "safari")
                }
            } header: {
                Text("Address")
            }

            Section {
                LabeledContent("Status", value: status?.text ?? "…")
            } footer: {
                if status == .notGuarding {
                    Text("Its owner removed this iPhone, or closed the wallet: it leaves this list at the next read.")
                }
            }

            if status == .guarding(recovery: nil) {
                Section {
                    Button {
                        scanning = true
                    } label: {
                        HStack {
                            Label("Start recovery", systemImage: "lifepreserver")
                            Spacer()
                            if reviewing { ProgressView() }
                        }
                    }
                    .disabled(reviewing)
                } footer: {
                    Text("Only when the owner lost their iPhone and asks you to: scan the key their new iPhone shows. The wallet pays the fee, and the owner can cancel during the delay.")
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingForget = true
                } label: {
                    Label("Forget this wallet", systemImage: "minus.circle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Guarded wallet")
        .refreshable { await refresh() }
        .confirmationDialog("Forget this wallet?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget wallet", role: .destructive, action: forget)
        } message: {
            Text("It leaves this iPhone's list for good, even if its owner names this iPhone again. Nothing changes on-chain: the wallet keeps this iPhone as guardian until its owner changes them.")
        }
        // The consent sheet waits for this one to be gone.
        .sheet(isPresented: $scanning, onDismiss: reviewScanned) {
            ScanSheet(title: "Start recovery", prompt: "Scan the key the owner's new iPhone shows.", read: newKey) {
                scanned = $0
            }
        }
    }

    private func newKey(_ text: String) throws -> DeviceKey {
        let key = try DeviceKey(text)
        guard key != deviceKey else { throw ScanRefusal("This is this iPhone's key: scan the one the new iPhone shows.") }
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

#Preview {
    NavigationStack {
        GuardedWalletView(
            address: try! PublicKey(base58: DemoConfig.recipient),
            explorerURL: URL(string: "https://explorer.solana.com/?cluster=devnet")!,
            status: .guarding(recovery: nil),
            deviceKey: try! DeviceKey("02e0552f7c3d1c0b59412b9211256544acbec3694d3240bd91dca7f2d2068e16ca"),
            refresh: {},
            review: { _ in },
            forget: {}
        )
    }
}
