//
//  DemoConfig.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import EnclaveKit
import Foundation

/// What belongs to this Mac and this demo: nothing else to edit before a run.
enum DemoConfig {
    /// Kora on the Mac, reached over Wi-Fi by its Bonjour name.
    static let enclaveKit = EnclaveKitConfig(relayerURL: URL(string: "http://NicolasnoMacBook-Pro.local:8080")!)
    /// The CLI wallet that funds the vault: the demo sends the SOL back home.
    static let recipient = "BvNwpwwQmEZyJdGwT6kpHXKTqHzBUteh9qfhQ7AnGNqE"
    static let amount = "0.01"
}
