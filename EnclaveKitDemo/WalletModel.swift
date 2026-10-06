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
            wallet = try client.createWallet()
        } catch {
            failure = error.localizedDescription
        }
        await refresh()
    }

    func refresh() async {
        guard let wallet else { return }
        do {
            balance = try await wallet.balance()
            status = try await wallet.status()
            guardians = try await wallet.guardians()
        } catch {
            failure = error.localizedDescription
        }
    }

    func reviewTransfer(_ amount: Lamports, to recipient: PublicKey) async {
        await review { try await $0.prepareTransfer(amount, to: recipient) }
    }

    /// The whole list, as it would be.
    func reviewGuardians(_ guardians: [DeviceKey]) async {
        await review { try await $0.prepareSetGuardians(guardians) }
    }

    func reviewCancelRecovery() async {
        await review { try await $0.prepareCancelRecovery() }
    }

    /// Checks the vault can pay, then opens the consent sheet. No Face ID yet.
    private func review(_ prepare: (Wallet) async throws -> ActionRequest) async {
        guard let wallet else { return }
        do {
            consent = Consent(request: try await prepare(wallet))
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Face ID, then Kora, then the cluster. A dismissed Face ID goes back
    /// to the review: nothing was signed.
    func authorize() async {
        guard let request = consent?.request else { return }
        consent?.phase = .authorizing
        do {
            let receipt = try await request.authorize()
            consent?.phase = .confirmed(explorerURL: receipt.explorerURL)
            await refresh()
        } catch EnclaveKitError.cancelled {
            consent?.phase = .review
        } catch {
            let explorerURL = (error as? EnclaveKitError)?.receipt?.explorerURL
            consent?.phase = .failed(message: error.localizedDescription, explorerURL: explorerURL)
        }
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
    var phase = Phase.review

    var id: UUID { request.id }
}
