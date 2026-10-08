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
    case move
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
                    confirming: model.confirming,
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
                            deviceKey: wallet.deviceKey,
                            guardians: model.guardians,
                            recoveryPending: recoveryPending,
                            refresh: model.refresh,
                            review: model.reviewGuardians
                        )
                    case .guarding:
                        GuardedWalletsView(
                            rows: model.guarded.map { .init(id: $0.id, address: $0.address, status: model.guardedStatuses[$0.id]) },
                            deviceKey: wallet.deviceKey,
                            failure: model.waitFailure,
                            refresh: model.refresh,
                            look: model.refreshGuarded
                        )
                    case let .guardedWallet(id):
                        if let guarded = model.guarded.first(where: { $0.id == id }) {
                            GuardedWalletView(
                                address: guarded.address,
                                explorerURL: guarded.explorerURL,
                                status: model.guardedStatuses[id],
                                deviceKey: wallet.deviceKey,
                                refresh: model.refresh,
                                review: { await model.reviewRecovery(of: id, to: $0) },
                                // Off the list: the `onChange` below goes back.
                                forget: { model.forgetWallet(id) }
                            )
                        }
                    case .recover:
                        RecoverView(
                            deviceKey: wallet.deviceKey,
                            candidates: model.recoverable?.map { .init(id: $0.id, address: $0.address) },
                            failure: model.waitFailure,
                            // Back to the wallet. Its own, moved back here,
                            // keeps its ID: the `onChange` below misses it.
                            look: { if await model.lookForWallets() { path.removeAll() } },
                            recover: { if await model.recoverWallet($0) { path.removeAll() } }
                        )
                    case .move:
                        MoveView(
                            deviceKey: wallet.deviceKey,
                            guardians: model.guardians,
                            moved: model.status == .keyReplaced,
                            recoveryPending: recoveryPending,
                            review: model.reviewMove
                        )
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
        // Each wallet shown, read here: the screen that switched wallets
        // goes, and SwiftUI cancels its task with it.
        .task(id: model.wallet?.id) { await model.refresh() }
        // A guarded wallet forgotten, or that no longer names this iPhone:
        // its screen goes.
        .onChange(of: model.guarded.map(\.id)) { _, ids in
            path.removeAll { if case let .guardedWallet(id) = $0 { !ids.contains(id) } else { false } }
        }
        // Whatever the screen, while a recovery comes to this iPhone. Ends
        // with it: confirmed, or cancelled by the old iPhone.
        .task(id: recovering) {
            if recovering { await model.confirmRecoveryWhenOpen() }
        }
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
                    // proposal included, stay on their screen, refreshed:
                    // a move's says it moved.
                    path.removeAll { $0 == .send }
                }
            )
        }
        .alert("Something went wrong", isPresented: showsFailure) {
        } message: {
            Text(model.failure ?? "")
        }
        .onAppear(perform: model.start)
    }

    private var showsFailure: Binding<Bool> {
        Binding { model.failure != nil } set: { if !$0 { model.failure = nil } }
    }

    private var recoveryPending: Bool {
        if case .active(recovery: .some) = model.status { true } else { false }
    }

    /// Toward this iPhone: it confirms on its own.
    private var recovering: Bool {
        if case .recovering = model.status { true } else { false }
    }
}
