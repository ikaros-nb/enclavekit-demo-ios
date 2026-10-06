//
//  RecoveryCountdown.swift
//  EnclaveKit demo
//
//  Created by Nicolas Bouème on 06/10/2026.
//

import SwiftUI

/// The recovery's delay, ticking down to `opensAt`: until then only the
/// owner acts, to cancel it. Past it, the new device may confirm.
struct RecoveryCountdown: View {
    let opensAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            LabeledContent("Delay") {
                if context.date < opensAt {
                    Text(timerInterval: context.date...opensAt, countsDown: true)
                        .monospacedDigit()
                } else {
                    Text("Over")
                }
            }
        }
    }
}

#Preview {
    Form {
        RecoveryCountdown(opensAt: .now + 60)
        RecoveryCountdown(opensAt: .now - 1)
    }
}
