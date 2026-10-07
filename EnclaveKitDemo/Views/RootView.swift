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
    case guarding
    case guardedWallet(Wallet.ID)
    case recover
    case close
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
                    guarding: model.guarded.count,
                    refresh: model.refresh,
                    cancelRecovery: model.reviewCancelRecovery,
                    confirmRecovery: model.confirmRecovery,
                    deleteDeviceKey: model.deleteDeviceKey
                )
                .navigationDestination(for: Screen.self) { screen in
                    switch screen {
                    case .send:
                        SendView(
                            recipient: DemoConfig.recipient,
                            amount: DemoConfig.amount,
                            review: model.reviewTransfer,
                            reviewAll: model.reviewTransferAll
                        )
                    case .guardians:
                        GuardiansView(
                            walletID: wallet.id,
                            deviceKey: wallet.deviceKey,
                            guardians: model.guardians,
                            recoveryPending: recoveryPending,
                            refresh: model.refresh,
                            review: model.reviewGuardians
                        )
                    case .guarding:
                        GuardedWalletsView(
                            rows: model.guarded.map { .init(id: $0.id, address: $0.address, status: model.guardedStatuses[$0.id]) },
                            walletID: wallet.id,
                            deviceKey: wallet.deviceKey,
                            refresh: model.refresh,
                            keep: model.guardWallet
                        )
                    case let .guardedWallet(id):
                        if let guarded = model.guarded.first(where: { $0.id == id }) {
                            GuardedWalletView(
                                id: id,
                                address: guarded.address,
                                explorerURL: guarded.explorerURL,
                                status: model.guardedStatuses[id],
                                deviceKey: wallet.deviceKey,
                                refresh: model.refresh,
                                review: { await model.reviewRecovery(of: id, to: $0) },
                                forget: {
                                    path.removeAll { $0 == .guardedWallet(id) }
                                    model.forgetWallet(id)
                                }
                            )
                        }
                    case .recover:
                        RecoverView(deviceKey: wallet.deviceKey, walletID: wallet.id, recover: model.recoverWallet)
                    case .close:
                        CloseView(destination: DemoConfig.recipient, guarding: model.guarded.count, review: model.reviewClose)
                    }
                }
            } else {
                EnrollView(create: model.createWallet)
            }
        }
        // Another wallet, or none: the screens pushed over the last one go.
        .onChange(of: model.wallet?.id) { path.removeAll() }
        .sheet(item: $model.consent) { consent in
            ConsentSheet(
                summary: consent.request.summary,
                maxFee: consent.request.maxFee,
                phase: consent.phase,
                authorize: model.authorize,
                close: { model.consent = nil },
                done: {
                    model.dismissConfirmed()
                    // Back to the wallet after a send, to the enroll screen
                    // after a close; the other actions, a guardian's
                    // proposal included, stay on their screen, refreshed.
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
