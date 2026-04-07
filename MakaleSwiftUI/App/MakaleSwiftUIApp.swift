import SwiftUI

@main
struct MakaleSwiftUIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.session == nil {
                    ActivationScreen()
                } else {
                    MainShellView()
                }
            }
            .environmentObject(appState)
            .task {
                await appState.bootstrap()
            }
            .sheet(item: $appState.activeDocument) { document in
                DocumentViewerScreen(document: document)
            }
            .sheet(item: $appState.activeVideo) { video in
                VideoPlayerScreen(video: video)
            }
            .alert(item: $appState.activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(alignment: .center) {
                if appState.isBusy {
                    BusyOverlay(
                        title: appState.loadingTitle,
                        detail: appState.loadingDetail,
                        progress: appState.loadingProgress
                    )
                }
            }
            .frame(minWidth: 1120, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1340, height: 860)
    }
}
