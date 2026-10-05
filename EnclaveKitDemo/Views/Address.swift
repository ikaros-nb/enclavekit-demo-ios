//
//  Address.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 05/10/2026.
//

import Foundation

extension Locale.Language {
    /// No linguistic content (ISO 639 "zxx"). Text typeset with it is never
    /// hyphenated: an address wraps without a hyphen that is not part of it.
    static let address = Locale.Language(identifier: "zxx")
}
