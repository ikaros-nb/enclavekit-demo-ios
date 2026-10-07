//
//  SendView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// Who and how much, or everything. Review stays off until both read as
/// valid: the SDK then checks the vault can pay, before any Face ID.
struct SendView: View {
    let review: (Lamports, PublicKey) async -> Void
    /// The whole balance: no amount to type.
    let reviewAll: (PublicKey) async -> Void
    @State private var recipient: String
    @State private var amount: String
    @State private var sendsAll: Bool
    @State private var reviewing = false

    init(
        recipient: String = "",
        amount: String = "",
        sendsAll: Bool = false,
        review: @escaping (Lamports, PublicKey) async -> Void,
        reviewAll: @escaping (PublicKey) async -> Void
    ) {
        self.review = review
        self.reviewAll = reviewAll
        _recipient = State(initialValue: recipient)
        _amount = State(initialValue: amount)
        _sendsAll = State(initialValue: sendsAll)
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

            Section {
                Toggle("Send all", isOn: $sendsAll)
                if !sendsAll {
                    HStack {
                        TextField("0.01", text: $amount)
                            .keyboardType(.decimalPad)
                        Text("SOL")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Amount")
            } footer: {
                if sendsAll {
                    Text("Everything the wallet holds, the fee aside: the program reads the amount as it sends. The wallet stays, and its address receives again.")
                }
            }

            Section {
                Button {
                    guard let address else { return }
                    Task {
                        reviewing = true
                        if sendsAll {
                            await reviewAll(address)
                        } else if let lamports {
                            await review(lamports, address)
                        }
                        reviewing = false
                    }
                } label: {
                    HStack {
                        Text("Review")
                        Spacer()
                        if reviewing { ProgressView() }
                    }
                }
                .disabled(address == nil || (!sendsAll && lamports == nil) || reviewing)
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
        SendView(recipient: DemoConfig.recipient, amount: DemoConfig.amount, review: { _, _ in }, reviewAll: { _ in })
    }
}

#Preview("Send all") {
    NavigationStack {
        SendView(recipient: DemoConfig.recipient, sendsAll: true, review: { _, _ in }, reviewAll: { _ in })
    }
}
