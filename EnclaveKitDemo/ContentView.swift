import EnclaveKit
import SwiftUI

struct ContentView: View {
    /// Kora on the Mac, reached over Wi-Fi by its Bonjour name.
    static let enclaveKit = EnclaveKitClient(config: EnclaveKitConfig(
        relayerURL: URL(string: "http://NicolasnoMacBook-Pro.local:8080")!
    ))
    static let lamports: UInt64 = 10_000_000

    @State private var wallet: Wallet?
    @State private var balance: Lamports?
    /// The CLI wallet that funds the vault: the SOL goes back home.
    @State private var destination = "BvNwpwwQmEZyJdGwT6kpHXKTqHzBUteh9qfhQ7AnGNqE"
    @State private var sending = false
    @State private var status = ""
    @State private var signature: String?

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
                Section("Send 0.01 SOL") {
                    TextField("Recipient", text: $destination)
                        .font(.footnote.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Send") { Task { await send() } }
                        .disabled(sending)
                }
            }
            Section {
                Text(status)
                if let signature, let url = URL(string: "https://explorer.solana.com/tx/\(signature)?cluster=devnet") {
                    Link("View in Explorer", destination: url)
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

    private func send() async {
        guard let wallet else { return }
        sending = true
        defer { sending = false }
        do {
            let to = try PublicKey(base58: destination)
            status = "Sending…"
            signature = nil
            signature = try await wallet.send(.transferSol(to: to, lamports: Self.lamports))
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
