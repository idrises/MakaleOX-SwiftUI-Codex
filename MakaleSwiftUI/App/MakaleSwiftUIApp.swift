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
#if os(macOS)
            .frame(minWidth: 1120, minHeight: 760)
#endif
        }
#if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1340, height: 860)
#endif

#if os(macOS)
        Window("Reader", id: "document-viewer") {
            DocumentWindowRoot()
                .environmentObject(appState)
                .alert(item: $appState.activeAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
        .defaultSize(width: 1180, height: 860)

        Window("Video", id: "video-viewer") {
            VideoWindowRoot()
                .environmentObject(appState)
                .alert(item: $appState.activeAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
        .defaultSize(width: 1280, height: 860)
#endif
    }
}

#if os(macOS)
private struct DocumentWindowRoot: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppCanvas {
            Group {
                if let document = appState.activeDocument {
                    DocumentViewerScreen(
                        document: document,
                        backLabel: "Close Window",
                        showsMetadataHeader: false,
                        onClose: {
                            appState.activeDocument = nil
                            dismiss()
                        }
                    )
                } else {
                    Color.clear
                        .task {
                            dismiss()
                        }
                }
            }
            .padding(24)
        }
        .onDisappear {
            appState.activeDocument = nil
        }
    }
}

private struct VideoWindowRoot: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppCanvas {
            Group {
                if let video = appState.activeVideo {
                    VideoPlayerScreen(
                        video: video,
                        backLabel: "Close Window",
                        onClose: {
                            appState.activeVideo = nil
                            dismiss()
                        }
                    )
                } else {
                    Color.clear
                        .task {
                            dismiss()
                        }
                }
            }
            .padding(24)
        }
        .onDisappear {
            appState.activeVideo = nil
        }
    }
}
#endif
