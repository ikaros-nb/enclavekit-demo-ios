//
//  RecoverView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// A new iPhone takes over a wallet with one code: the iPhone that signs for
/// it, or a guardian if that one is lost, scans this iPhone's key. This
/// screen then finds the wallet on-chain and takes it on. This iPhone's own
/// wallet, moved away, comes back the same way.
struct RecoverView: View {
    /// A wallet waiting for this iPhone's key.
    struct Candidate: Identifiable {
        let id: Wallet.ID
        let address: PublicKey
    }

    let deviceKey: DeviceKey
    /// `nil` until read. A single one is taken on without a choice.
    let candidates: [Candidate]?
    /// Why the last read failed: the screen tries again all the same.
    let failure: String?
    /// One read of the chain, every few seconds.
    let look: () async -> Void
    let recover: (Wallet.ID) async -> Void
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
                if choosing, let candidates {
                    ForEach(candidates) { candidate in
                        Button {
                            Task {
                                recovering = true
                                await recover(candidate.id)
                                recovering = false
                            }
                        } label: {
                            // Its vault, as the other iPhone's screen shows it.
                            Text(candidate.address.base58)
                                .font(.footnote.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .disabled(recovering)
                } else {
                    LabeledContent("Waiting for the wallet") {
                        ProgressView()
                    }
                }
            } header: {
                Text(choosing ? "2. Choose the wallet" : "2. Wait for the wallet")
            } footer: {
                if let failure {
                    Text("\(failure) Trying again.")
                        .foregroundStyle(.red)
                } else if choosing {
                    Text("Several wallets wait for this iPhone's key: pick yours by its address.")
                } else {
                    Text("This iPhone finds it on its own. After a move, it signs at once; after a guardian's proposal, it confirms once the delay is over.")
                }
            }
        }
        .navigationTitle("Recover a wallet")
        .polling(look)
    }

    private var choosing: Bool {
        (candidates?.count ?? 0) > 1
    }
}

#Preview {
    NavigationStack {
        RecoverView(
            deviceKey: try! DeviceKey("02b215cb41f4972504ed49327411f0784a5378476f42a07d6f4cd21d0261c3e9d0"),
            candidates: nil,
            failure: nil,
            look: {},
            recover: { _ in }
        )
    }
}
