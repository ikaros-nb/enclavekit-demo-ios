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
    /// The wallets this device guards, in the order it took them on.
    private(set) var guarded: [GuardedWallet] = []
    /// Each guarded wallet's, read with the rest.
    private(set) var guardedStatuses: [Wallet.ID: GuardedWallet.Status] = [:]
    /// The action in the consent sheet, from review to receipt.
    var consent: Consent?
    /// What went wrong outside the consent sheet, shown in an alert.
    var failure: String?

    init(client: EnclaveKitClient) {
        self.client = client
    }

    /// At launch: this device's wallet if it has one, then its balance.
    func start() async {
        do {
            wallet = try client.wallet()
        } catch {
            failure = error.localizedDescription
        }
        await refresh()
    }

    /// Makes the key in the Secure Enclave: no network, no Face ID.
    func createWallet() async {
        do {
            show(try client.createWallet())
        } catch {
            failure = error.localizedDescription
        }
        await refresh()
    }

    /// Takes on the wallet a guardian proposed this device's key for, or
    /// another device moved to it, this device's own wallet back included:
    /// the SDK checks on-chain first. `false` on a failure.
    func recoverWallet(_ id: Wallet.ID) async -> Bool {
        do {
            show(try await client.recoverWallet(id))
            await refresh()
            return true
        } catch {
            failure = error.localizedDescription
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
    }

    func refresh() async {
        guard let wallet else { return }
        do {
            balance = try await wallet.balance()
            status = try await wallet.status()
            guardians = try await wallet.guardians()
            guarded = try client.guardedWallets()
            for guardedWallet in guarded {
                guardedStatuses[guardedWallet.id] = try await guardedWallet.status()
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Keeps the wallet, scanned on its owner's device, among those this one
    /// guards: the Keychain only.
    func guardWallet(_ id: Wallet.ID) async {
        do {
            _ = try client.guardWallet(id)
        } catch {
            failure = error.localizedDescription
        }
        await refresh()
    }

    /// Takes the wallet off this device's list: the Keychain only. The
    /// wallet still names this device until its owner changes its guardians.
    func forgetWallet(_ id: Wallet.ID) {
        do {
            try client.forgetWallet(id)
            guarded = try client.guardedWallets()
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

    /// On the new device, once the delay is over. Nothing to sign, no Face
    /// ID: the relayer pays the fee.
    func confirmRecovery() async {
        guard let wallet else { return }
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
