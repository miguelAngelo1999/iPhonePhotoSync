import SwiftUI

@main
struct iPhonePhotoSyncApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 420)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 520, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
