import EnclaveKit
import SwiftUI

@main struct MyApp: App {
    @State private var model = WalletModel(client: EnclaveKitClient(config: DemoConfig.enclaveKit))

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
