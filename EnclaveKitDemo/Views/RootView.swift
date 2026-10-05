//
//  RootView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// The enroll screen until the wallet exists, then the wallet, its send
/// screen and the consent sheet. The only view that sees the model: it
/// hands each screen plain values and the model's actions.
struct RootView: View {
    @Bindable var model: WalletModel
    @State private var sending = false

    var body: some View {
        NavigationStack {
            if let wallet = model.wallet {
                WalletView(
                    address: wallet.address,
                    explorerURL: wallet.explorerURL,
                    balance: model.balance,
                    status: model.status,
                    refresh: model.refresh,
                    send: { sending = true }
                )
                .navigationDestination(isPresented: $sending) {
                    SendView(recipient: DemoConfig.recipient, amount: DemoConfig.amount, review: model.review)
                }
            } else {
                EnrollView(create: model.createWallet)
            }
        }
        .sheet(item: $model.consent) { consent in
            ConsentSheet(
                summary: consent.request.summary,
                maxFee: consent.request.maxFee,
                phase: consent.phase,
                authorize: model.authorize,
                close: { model.consent = nil },
                done: {
                    model.consent = nil
                    sending = false
                }
            )
        }
        .alert("Something went wrong", isPresented: showsFailure) {
        } message: {
            Text(model.failure ?? "")
        }
        .task { await model.start() }
    }

    private var showsFailure: Binding<Bool> {
        Binding { model.failure != nil } set: { if !$0 { model.failure = nil } }
    }
}
