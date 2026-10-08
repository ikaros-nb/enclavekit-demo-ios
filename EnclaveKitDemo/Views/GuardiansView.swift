//
//  GuardiansView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import EnclaveKit
import SwiftUI

/// The owner's side of the guardians: who they are, adding one by scanning
/// its key, removing one. A guardian finds the wallet on its own. Every
/// change is one Face ID, the whole list replaced.
struct GuardiansView: View {
    /// This device's: never its own guardian.
    let deviceKey: DeviceKey
    /// `nil` until read.
    let guardians: [DeviceKey]?
    /// Changing the list cancels it too.
    let recoveryPending: Bool
    let refresh: () async -> Void
    /// The list as it would be, for the consent sheet.
    let review: ([DeviceKey]) async -> Void
    @State private var scanning = false
    @State private var scanned: DeviceKey?
    @State private var reviewing = false

    var body: some View {
        Form {
            Section {
                if let guardians {
                    if guardians.isEmpty {
                        Text("No guardian yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(guardians, id: \.self) { guardian in
                        // Its ends tell it from the others, as on its screen.
                        Text(guardian.description)
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .swipeActions {
                                // Not a delete: the row stays until the
                                // change is authorized and confirmed.
                                Button("Remove", systemImage: "trash") {
                                    change(to: guardians.filter { $0 != guardian })
                                }
                                .tint(.red)
                            }
                    }
                } else {
                    ProgressView()
                }

                Button {
                    scanning = true
                } label: {
                    HStack {
                        Label("Add guardian", systemImage: "qrcode.viewfinder")
                        Spacer()
                        if reviewing { ProgressView() }
                    }
                }
                .disabled((guardians?.count ?? Wallet.maxGuardians) >= Wallet.maxGuardians || reviewing)
            } footer: {
                Text(footer)
            }
        }
        .navigationTitle("Guardians")
        .refreshable { await refresh() }
        // The consent sheet waits for this one to be gone.
        .sheet(isPresented: $scanning, onDismiss: addScanned) {
            ScanSheet(title: "Add guardian", prompt: "Scan the key your guardian's device shows.", read: newGuardian) {
                scanned = $0
            }
        }
    }

    private var footer: String {
        let about = "Devices you trust, up to \(Wallet.maxGuardians): scan the key each one shows in its Guarding screen, where this wallet then appears. If you lose this iPhone, one of them can move the wallet to your new one, after a delay during which you can cancel."
        return recoveryPending ? about + " Changing them cancels the recovery in progress." : about
    }

    /// A device key, neither this device's nor a guardian already.
    private func newGuardian(_ text: String) throws -> DeviceKey {
        let key = try DeviceKey(text)
        guard key != deviceKey else { throw ScanRefusal("This is this iPhone's own key: a guardian is another device.") }
        guard guardians?.contains(key) != true else { throw ScanRefusal("This device is a guardian already.") }
        return key
    }

    private func addScanned() {
        guard let scanned, let guardians else { return }
        self.scanned = nil
        change(to: guardians + [scanned])
    }

    private func change(to guardians: [DeviceKey]) {
        Task {
            reviewing = true
            await review(guardians)
            reviewing = false
        }
    }
}

#Preview {
    NavigationStack {
        GuardiansView(
            deviceKey: try! DeviceKey("02b215cb41f4972504ed49327411f0784a5378476f42a07d6f4cd21d0261c3e9d0"),
            guardians: [try! DeviceKey("02e0552f7c3d1c0b59412b9211256544acbec3694d3240bd91dca7f2d2068e16ca")],
            recoveryPending: false,
            refresh: {},
            review: { _ in }
        )
    }
}
