//
//  EnrollView.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import SwiftUI

/// First launch: this device has no key yet.
struct EnrollView: View {
    let create: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No wallet yet", systemImage: "lock.shield")
        } description: {
            Text("Its key is made inside this iPhone's Secure Enclave and never leaves it. Face ID approves every send.")
        } actions: {
            Button("Create wallet") { Task { await create() } }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("EnclaveKit")
    }
}

#Preview {
    NavigationStack {
        EnrollView(create: {})
    }
}
