//
//  Polling.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 08/10/2026.
//

import SwiftUI

extension View {
    /// Runs `read` now, then every `interval` while the view is on screen:
    /// what another iPhone does shows here without a pull. Three seconds
    /// keep devnet's public RPC well under its rate limit.
    func polling(every interval: Duration = .seconds(3), _ read: @escaping () async -> Void) -> some View {
        task {
            while !Task.isCancelled {
                await read()
                try? await Task.sleep(for: interval)
            }
        }
    }
}
