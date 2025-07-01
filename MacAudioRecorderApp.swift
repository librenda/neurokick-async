import SwiftUI
import SwiftData

@main
struct MacAudioRecorderApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .frame(minWidth: 800, minHeight: 600)
                .modelContainer(for: RecordingSession.self)
        }
    }
}

@available(macOS 12.0, *)
struct MainTabView: View {
    // Active session state - shared across tabs
    @State private var activeSession: RecordingSession?
    
    var body: some View {
        TabView {
            CombinedRecordingView(activeSession: $activeSession)
                .tabItem {
                    Label("Recording", systemImage: "mic")
                }
            
            DailySummaryView()
                .tabItem {
                    Label("Daily Analysis", systemImage: "chart.bar")
                }
            
            SessionsListView(activeSession: $activeSession)
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet")
                }
        }
    }
}
