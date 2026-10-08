//
//  WalletModel.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import Foundation
import Observation

/// The demo's state, and the SDK calls behind its buttons. Only `RootView`
/// sees it: the screens get plain values, so their previews need no
/// Secure Enclave.
@Observable final class WalletModel {
    private let client: EnclaveKitClient
    /// `nil` until the user creates it: the enroll screen until then.
    private(set) var wallet: Wallet?
    private(set) var balance: Lamports?
    private(set) var status: Wallet.Status?
    /// None before the first action.
    private(set) var guardians: [DeviceKey]?
    /// The wallets that name this device as guardian, read on-chain.
    private(set) var guarded: [GuardedWallet] = []
    /// Each guarded wallet's, read with the rest.
    private(set) var guardedStatuses: [Wallet.ID: GuardedWallet.Status] = [:]
    /// The wallets waiting for this device's key, `nil` until read: Recover
    /// a wallet offers them when there are several.
    private(set) var recoverable: [Wallet]?
    /// Why the last read of a screen that waits failed, `nil` once one works
    /// again: that screen says it, and tries again. Like `failure`, never a
    /// cancelled task's.
    private(set) var waitFailure: String?
    /// A recovery toward this device being confirmed, on its own or by the
    /// button: one at a time.
    private(set) var confirming = false
    /// The action in the consent sheet, from review to receipt.
    var consent: Consent?
    /// What went wrong outside the consent sheet, shown in an alert. Not
    /// what a cancelled task met: SwiftUI cancels a screen's task as the
    /// screen goes, and the recovery's once it is over. Nothing went wrong
    /// then.
    var failure: String?

    init(client: EnclaveKitClient) {
        self.client = client
    }

    /// At launch: this device's wallet if it has one. `RootView` reads the
    /// rest, as for any wallet shown.
    func start() {
        do {
            wallet = try client.wallet()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Makes the key in the Secure Enclave: no network, no Face ID.
    func createWallet() {
        do {
            show(try client.createWallet())
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Recover a wallet's wait: the wallets waiting for this device's key,
    /// and the status of the one on screen, read again. A single wallet is
    /// taken on at once; several wait for the user's choice. `true` once
    /// there is nothing left to wait for: this device's own wallet came
    /// back, or it took one on.
    func lookForWallets() async -> Bool {
        guard let wallet else { return false }
        do {
            status = try await wallet.status()
            switch status {
            case .active, .recovering: return true
            case .notOnChainYet, .keyReplaced, nil: break
            }
            let found = try await client.recoverableWallets()
            recoverable = found
            waitFailure = nil
            if found.count == 1, let only = found.first { return await recoverWallet(only.id) }
        } catch {
            if !Task.isCancelled { waitFailure = error.localizedDescription }
        }
        return false
    }

    /// Takes on one of the wallets waiting for this device's key: the SDK
    /// checks on-chain first. `false` on a failure. `RootView` reads the
    /// wallet: Recover a wallet, whose task this runs in, goes with it.
    func recoverWallet(_ id: Wallet.ID) async -> Bool {
        do {
            show(try await client.recoverWallet(id))
            return true
        } catch {
            if !Task.isCancelled { failure = error.localizedDescription }
            return false
        }
    }

    /// The demo's way to lose this iPhone: back to the enroll screen, the
    /// wallet left on-chain for a guardian to move.
    func deleteDeviceKey() {
        do {
            try client.deleteDeviceKey()
            show(nil)
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Another wallet, or none: nothing of the previous one stays on screen.
    private func show(_ wallet: Wallet?) {
        self.wallet = wallet
        balance = nil
        status = nil
        guardians = nil
        guarded = []
        guardedStatuses = [:]
        recoverable = nil
        waitFailure = nil
    }

    func refresh() async {
        guard let wallet else { return }
        do {
            balance = try await wallet.balance()
            status = try await wallet.status()
            guardians = try await wallet.guardians()
            try await readGuarded()
        } catch {
            if !Task.isCancelled { failure = error.localizedDescription }
        }
    }

    /// Guarding's wait: the wallets that name this device, so that one
    /// shows as soon as its owner adds this device.
    func refreshGuarded() async {
        do {
            try await readGuarded()
            waitFailure = nil
        } catch {
            if !Task.isCancelled { waitFailure = error.localizedDescription }
        }
    }

    /// The list and the statuses replaced together: a wallet that no longer
    /// names this device leaves both.
    private func readGuarded() async throws {
        let found = try await client.guardedWallets()
        var statuses: [Wallet.ID: GuardedWallet.Status] = [:]
        for guardedWallet in found {
            statuses[guardedWallet.id] = try await guardedWallet.status()
        }
        guarded = found
        guardedStatuses = statuses
    }

    /// Takes the wallet off this device's list for good: the Keychain only.
    /// The wallet still names this device until its owner changes its
    /// guardians.
    func forgetWallet(_ id: Wallet.ID) {
        do {
            try client.forgetWallet(id)
            guarded.removeAll { $0.id == id }
            guardedStatuses[id] = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    func reviewTransfer(_ amount: Lamports, to recipient: PublicKey) async {
        guard let wallet else { return }
        await review { try await wallet.prepareTransfer(amount, to: recipient) }
    }

    /// Everything the vault holds, the fee aside: the program reads the
    /// amount as it executes.
    func reviewTransferAll(to recipient: PublicKey) async {
        guard let wallet else { return }
        await review { try await wallet.prepareTransferAll(to: recipient) }
    }

    /// Everything to `destination`, then the key goes once confirmed. A
    /// wallet that never acted and holds less than the fee has nothing to
    /// send: only the key goes, at once.
    func reviewClose(to destination: PublicKey) async {
        guard let wallet else { return }
        do {
            consent = Consent(request: try await wallet.prepareClose(to: destination), closesWallet: true)
        } catch EnclaveKitError.nothingToClose {
            deleteDeviceKey()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// The whole list, as it would be.
    func reviewGuardians(_ guardians: [DeviceKey]) async {
        guard let wallet else { return }
        await review { try await wallet.prepareSetGuardians(guardians) }
    }

    func reviewCancelRecovery() async {
        guard let wallet else { return }
        await review { try await wallet.prepareCancelRecovery() }
    }

    /// To the key another device shows, at once: once confirmed, this device
    /// no longer signs for the wallet.
    func reviewMove(to newKey: DeviceKey) async {
        guard let wallet else { return }
        await review { try await wallet.prepareMove(to: newKey) }
    }

    /// As a guardian of `id`: proposes the key its owner's new device shows.
    func reviewRecovery(of id: Wallet.ID, to newKey: DeviceKey) async {
        guard let guarded = guarded.first(where: { $0.id == id }) else { return }
        await review { try await guarded.prepareRecovery(to: newKey) }
    }

    /// Checks the vault can pay, then opens the consent sheet. No Face ID yet.
    private func review(_ prepare: () async throws -> ActionRequest) async {
        do {
            consent = Consent(request: try await prepare())
        } catch {
            failure = error.localizedDescription
        }
    }

    /// On the new device, while the wallet is `recovering`: waits for the
    /// delay, then confirms. Nothing to sign, no Face ID: the relayer pays
    /// the fee. A guardian who proposes again pushes the delay back, the
    /// SDK waits on. The button stays off meanwhile, for a failure only. A
    /// cancelled wait, the recovery gone, says nothing.
    func confirmRecoveryWhenOpen() async {
        guard let wallet else { return }
        confirming = true
        defer { confirming = false }
        do {
            _ = try await wallet.confirmRecoveryWhenOpen()
            // The relayer paid, the guardians stay: only the status moves.
            // Read last: `active`, it ends the task this runs in.
            status = try await wallet.status()
        } catch {
            if Task.isCancelled { return }
            failure = error.localizedDescription
            await refresh()
        }
    }

    /// The button, once the delay is over and the confirmation on its own
    /// failed.
    func confirmRecovery() async {
        guard let wallet, !confirming else { return }
        confirming = true
        defer { confirming = false }
        do {
            _ = try await wallet.confirmRecovery()
        } catch {
            failure = error.localizedDescription
        }
        await refresh()
    }

    /// Face ID, then Kora, then the cluster. A dismissed Face ID goes back
    /// to the review: nothing was signed.
    func authorize() async {
        guard let request = consent?.request else { return }
        consent?.phase = .authorizing
        do {
            let receipt = try await request.authorize()
            consent?.phase = .confirmed(explorerURL: receipt.explorerURL)
            // A closed wallet took the key along: nothing left to read.
            if consent?.closesWallet != true { await refresh() }
        } catch EnclaveKitError.cancelled {
            consent?.phase = .review
        } catch {
            let explorerURL = (error as? EnclaveKitError)?.receipt?.explorerURL
            consent?.phase = .failed(message: error.localizedDescription, explorerURL: explorerURL)
        }
    }

    /// Done, once confirmed. A closed wallet took the key along: back to the
    /// enroll screen.
    func dismissConfirmed() {
        if consent?.closesWallet == true { show(nil) }
        consent = nil
    }
}

/// An action in the consent sheet, and where it stands.
struct Consent: Identifiable {
    enum Phase {
        case review
        /// Face ID, then Kora, then the cluster: one `authorize()`.
        case authorizing
        case confirmed(explorerURL: URL)
        /// `explorerURL` once the transaction reached the network.
        case failed(message: String, explorerURL: URL?)
    }

    let request: ActionRequest
    /// Confirmed, it deleted the key: Done goes back to the enroll screen.
    var closesWallet = false
    var phase = Phase.review

    var id: UUID { request.id }
}
