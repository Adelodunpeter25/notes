import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        if authStore.isAuthenticated {
            MainView()
        } else {
            LoginView()
                .frame(width: 380, height: 420)
        }
    }
}
