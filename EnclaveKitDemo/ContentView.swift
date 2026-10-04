import EnclaveKit
import SwiftUI

struct ContentView: View {
    /// Kora on the Mac, reached over Wi-Fi by its Bonjour name.
    static let kora = Kora(url: URL(string: "http://NicolasnoMacBook-Pro.local:8080")!)
    static let lamports: UInt64 = 10_000_000

    @State private var wallet: Wallet?
    @State private var relayer: PublicKey?
    @State private var balance: UInt64?
    /// The CLI wallet that funds the vault: the SOL goes back home.
    @State private var destination = "BvNwpwwQmEZyJdGwT6kpHXKTqHzBUteh9qfhQ7AnGNqE"
    @State private var sending = false
    @State private var status = ""
    @State private var signature: String?

    var body: some View {
        Form {
            if let wallet {
                Section("Vault") {
                    Text(wallet.vaultAddress.base58)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button("Copy address") { UIPasteboard.general.string = wallet.vaultAddress.base58 }
                    LabeledContent("Balance", value: balance.map(sol) ?? "…")
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
                LabeledContent("Relayer", value: relayer?.base58 ?? "…")
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
            let wallet = Wallet(signer: try SecureEnclaveKey.loadOrCreate(), kora: Self.kora)
            self.wallet = wallet
            print("vault \(wallet.vaultAddress)")
            await refresh()
            // First local request: iOS asks for the Local Network permission
            // here, before any Face ID.
            relayer = try await Self.kora.payerSigner()
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

    private func sol(_ lamports: UInt64) -> String {
        (Double(lamports) / 1_000_000_000).formatted(.number.precision(.fractionLength(0...9)).locale(Locale(identifier: "en_US_POSIX"))) + " SOL"
    }
}

#Preview {
    ContentView()
}
