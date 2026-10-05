//
//  SendView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// Who and how much. Review stays off until both read as valid: the SDK
/// then checks the vault can pay, before any Face ID.
struct SendView: View {
    let review: (Lamports, PublicKey) async -> Void
    @State private var recipient: String
    @State private var amount: String
    @State private var reviewing = false

    init(recipient: String = "", amount: String = "", review: @escaping (Lamports, PublicKey) async -> Void) {
        self.review = review
        _recipient = State(initialValue: recipient)
        _amount = State(initialValue: amount)
    }

    var body: some View {
        Form {
            Section {
                // One line: a field that wraps hyphenates the address.
                TextField("Solana address", text: $recipient)
                    .font(.footnote.monospaced())
                    .minimumScaleFactor(0.5)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Recipient")
            } footer: {
                if !recipient.isEmpty && address == nil {
                    Text("Not a Solana address.")
                }
            }

            Section("Amount") {
                HStack {
                    TextField("0.01", text: $amount)
                        .keyboardType(.decimalPad)
                    Text("SOL")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    guard let lamports, let address else { return }
                    Task {
                        reviewing = true
                        await review(lamports, address)
                        reviewing = false
                    }
                } label: {
                    HStack {
                        Text("Review")
                        Spacer()
                        if reviewing { ProgressView() }
                    }
                }
                .disabled(lamports == nil || address == nil || reviewing)
            }
        }
        .navigationTitle("Send")
    }

    /// Zero is no transfer.
    private var lamports: Lamports? {
        guard let lamports = Lamports(sol: amount), lamports > 0 else { return nil }
        return lamports
    }

    private var address: PublicKey? {
        try? PublicKey(base58: recipient.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

#Preview {
    NavigationStack {
        SendView(recipient: DemoConfig.recipient, amount: DemoConfig.amount) { _, _ in }
    }
}
