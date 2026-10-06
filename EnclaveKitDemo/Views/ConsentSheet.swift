//
//  ConsentSheet.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// What the user approves, addresses in full, before Face ID; then how it
/// went. Only its buttons close it: none while authorizing.
struct ConsentSheet: View {
    let summary: String
    let maxFee: Lamports
    let phase: Consent.Phase
    let authorize: () async -> Void
    /// Back to the send screen: before Face ID, or after a failure.
    let close: () -> Void
    /// Back to the wallet, once confirmed.
    let done: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(summary)
                        .typesettingLanguage(.address)
                    LabeledContent("Fee up to", value: maxFee.formatted)
                } footer: {
                    Text("Paid back to the relayer that sends the transaction. The wallet's first action also pays the rent of its account.")
                }

                Section {
                    switch phase {
                    case .review:
                        Button("Authorize with Face ID", systemImage: "faceid") {
                            Task { await authorize() }
                        }
                    case .authorizing:
                        LabeledContent("Authorizing") { ProgressView() }
                    case let .confirmed(explorerURL):
                        Label("Confirmed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Link("View in Explorer", destination: explorerURL)
                    case let .failed(message, explorerURL):
                        Label {
                            Text(message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        if let explorerURL {
                            Link("View in Explorer", destination: explorerURL)
                        }
                    }
                }
            }
            .navigationTitle("Approve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .review = phase { Button("Cancel", action: close) }
                    if case .failed = phase { Button("Close", action: close) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .confirmed = phase { Button("Done", action: done) }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

#Preview("Review") {
    ConsentSheet(
        summary: "Send 0.01 SOL to \(DemoConfig.recipient)",
        maxFee: 1_823_560,
        phase: .review,
        authorize: {}, close: {}, done: {}
    )
}

#Preview("Confirmed") {
    ConsentSheet(
        summary: "Send 0.01 SOL to \(DemoConfig.recipient)",
        maxFee: 10_000,
        phase: .confirmed(explorerURL: URL(string: "https://explorer.solana.com/?cluster=devnet")!),
        authorize: {}, close: {}, done: {}
    )
}

#Preview("Failed") {
    ConsentSheet(
        summary: "Send 0.01 SOL to \(DemoConfig.recipient)",
        maxFee: 10_000,
        phase: .failed(message: "The relayer refused the transaction, nothing was sent: Invalid transaction", explorerURL: nil),
        authorize: {}, close: {}, done: {}
    )
}
