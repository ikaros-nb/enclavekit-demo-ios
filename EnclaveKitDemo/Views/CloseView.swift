//
//  CloseView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 07/10/2026.
//

import EnclaveKit
import SwiftUI

/// The demo's way to start over: everything goes to `destination`, the
/// wallet's account closes, then this iPhone's key goes. All of it said
/// before the button: a wallet with nothing to send loses its key without
/// a consent sheet.
struct CloseView: View {
    /// How many wallets this iPhone guards: its key signs for them too.
    let guarding: Int
    let review: (PublicKey) async -> Void
    @State private var destination: String
    @State private var reviewing = false

    init(destination: String = "", guarding: Int, review: @escaping (PublicKey) async -> Void) {
        self.guarding = guarding
        self.review = review
        _destination = State(initialValue: destination)
    }

    var body: some View {
        Form {
            Section {
                // One line: a field that wraps hyphenates the address.
                TextField("Solana address", text: $destination)
                    .font(.footnote.monospaced())
                    .minimumScaleFactor(0.5)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Send everything to")
            } footer: {
                if !destination.isEmpty && address == nil {
                    Text("Not a Solana address.")
                }
            }

            Section {
                Label("Everything the wallet holds goes to this address, the fee aside. Then its account closes.", systemImage: "paperplane")
                Label("This iPhone's key is deleted: nothing signs for this wallet again. SOL sent to its address afterwards is lost.", systemImage: "key.slash")
                if guarding > 0 {
                    Label("This iPhone stops guarding \(guarding == 1 ? "the wallet it guards" : "the \(guarding) wallets it guards"): the same key signs as guardian.", systemImage: "shield.slash")
                }
            } header: {
                Text("What happens")
            }

            Section {
                Button(role: .destructive) {
                    guard let address else { return }
                    Task {
                        reviewing = true
                        await review(address)
                        reviewing = false
                    }
                } label: {
                    HStack {
                        Label("Close wallet", systemImage: "xmark.bin")
                        Spacer()
                        if reviewing { ProgressView() }
                    }
                    // The role reddens the text only, and red stays red
                    // once disabled.
                    .foregroundStyle(address == nil ? Color.secondary : Color.red)
                }
                .disabled(address == nil || reviewing)
            } footer: {
                Text("You approve the close next. A wallet never used that holds less than the fee has nothing to send: its key is deleted at once.")
            }
        }
        .navigationTitle("Close wallet")
    }

    private var address: PublicKey? {
        try? PublicKey(base58: destination.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

#Preview {
    NavigationStack {
        CloseView(destination: DemoConfig.recipient, guarding: 1) { _ in }
    }
}
