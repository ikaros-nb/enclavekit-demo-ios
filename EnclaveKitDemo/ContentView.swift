import EnclaveKit
import SwiftUI

struct ContentView: View {
    /// Kora on the Mac, reached over Wi-Fi by its Bonjour name.
    static let enclaveKit = EnclaveKitClient(config: EnclaveKitConfig(
        relayerURL: URL(string: "http://NicolasnoMacBook-Pro.local:8080")!
    ))
    static let amount: Lamports = 10_000_000

    @State private var wallet: Wallet?
    @State private var balance: Lamports?
    /// The CLI wallet that funds the vault: the SOL goes back home.
    @State private var destination = "BvNwpwwQmEZyJdGwT6kpHXKTqHzBUteh9qfhQ7AnGNqE"
    @State private var busy = false
    @State private var status = ""
    @State private var request: ActionRequest?
    @State private var receipt: Receipt?

    var body: some View {
        Form {
            if let wallet {
                Section("Vault") {
                    Text(wallet.address.base58)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button("Copy address") { UIPasteboard.general.string = wallet.address.base58 }
                    LabeledContent("Balance", value: balance?.formatted ?? "…")
                    Button("Refresh") { Task { await refresh() } }
                }
                Section("Send \(Self.amount.formatted)") {
                    TextField("Recipient", text: $destination)
                        .font(.footnote.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Review") { Task { await review(wallet) } }
                        .disabled(busy)
                }
            }
            if let request {
                Section("Review") {
                    Text(request.summary)
                    LabeledContent("Fee up to", value: request.maxFee.formatted)
                    Button("Authorize with Face ID") { Task { await authorize(request) } }
                        .disabled(busy)
                }
            }
            Section {
                Text(status)
                if let receipt {
                    Link("View in Explorer", destination: receipt.explorerURL)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let wallet = try Self.enclaveKit.wallet() ?? Self.enclaveKit.createWallet()
            self.wallet = wallet
            print("vault \(wallet.address)")
            await refresh()
        } catch {
            status = "\(error)"
        }
    }

    private func refresh() async {
        do {
            balance = try await wallet?.balance()
        } catch {
            status = "\(error)"
        }
    }

    /// Reads the wallet and checks the vault can pay: no Face ID yet.
    private func review(_ wallet: Wallet) async {
        busy = true
        defer { busy = false }
        do {
            receipt = nil
            status = ""
            request = try await wallet.prepareTransfer(Self.amount, to: try PublicKey(base58: destination))
        } catch {
            request = nil
            status = "\(error)"
        }
    }

    private func authorize(_ request: ActionRequest) async {
        busy = true
        defer { busy = false }
        do {
            status = "Sending…"
            receipt = try await request.authorize()
            self.request = nil
            status = "Confirmed"
            await refresh()
        } catch {
            status = "\(error)"
        }
    }
}

#Preview {
    ContentView()
}
