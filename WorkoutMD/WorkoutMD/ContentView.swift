import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vaultService: VaultService

    var body: some View {
        Group {
            if vaultService.vaultURL == nil {
                VaultSetupView()
            } else {
                TabView {
                    NavigationStack {
                        TemplatePickerView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    NavigationLink(destination: SettingsView()) {
                                        Image(systemName: "gear")
                                    }
                                }
                            }
                    }
                    .tabItem { Label("Home", systemImage: "house") }

                    NavigationStack {
                        OverviewView()
                    }
                    .tabItem { Label("Overview", systemImage: "calendar") }
                }
            }
        }
    }
}
