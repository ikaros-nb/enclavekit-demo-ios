//
//  RootView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import SwiftUI

/// The screens pushed over the wallet.
enum Screen: Hashable {
    case send
    case guardians
}

/// The enroll screen until the wallet exists, then the wallet, the screens
/// it pushes and the consent sheet. The only view that sees the model: it
/// hands each screen plain values and the model's actions.
struct RootView: View {
    @Bindable var model: WalletModel
    @State private var path: [Screen] = []

    var body: some View {
        NavigationStack(path: $path) {
            if let wallet = model.wallet {
                WalletView(
                    address: wallet.address,
                    explorerURL: wallet.explorerURL,
                    balance: model.balance,
                    status: model.status,
                    guardians: model.guardians?.count,
                    refresh: model.refresh,
                    cancelRecovery: model.reviewCancelRecovery
                )
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .send:
                        SendView(recipient: DemoConfig.recipient, amount: DemoConfig.amount, review: model.reviewTransfer)
                    case .guardians:
                        GuardiansView(
                            walletID: wallet.id,
                            deviceKey: wallet.deviceKey,
                            guardians: model.guardians,
                            recoveryPending: recoveryPending,
                            refresh: model.refresh,
                            review: model.reviewGuardians
                        )
                    }
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
                    // Back to the wallet after a send; the other actions
                    // stay on their screen, refreshed.
                    path.removeAll { $0 == .send }
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

    private var recoveryPending: Bool {
        if case .active(_, recovery: .some) = model.status { true } else { false }
    }
}
