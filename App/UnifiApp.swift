import SwiftUI
import FirebaseCore
import FirebaseAppCheck

final class AttestationFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

@main
struct UnifiApp: App {
    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AttestationFactory())
            #endif
            FirebaseApp.configure()
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
