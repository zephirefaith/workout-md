import SwiftUI

@main
struct WorkoutMDApp: App {
    @StateObject private var vaultService = VaultService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultService)
        }
    }
}
