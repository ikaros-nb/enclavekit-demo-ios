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
            Text("Its key is made inside this iPhone's Secure Enclave and never leaves it. You approve every action as you unlock this iPhone.\n\nReplacing a lost iPhone? Create one all the same: a guardian moves the lost wallet to its key.")
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
