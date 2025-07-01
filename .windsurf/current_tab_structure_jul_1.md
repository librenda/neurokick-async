# Current Tab Structure (July 1)

The MacAudioRecorder application consists of 3 main tabs:

## 1. Recording Tab
- **View**: `CombinedRecordingView`
- **Icon**: Microphone (systemImage: "mic")
- **Purpose**: Main recording interface where users can record and analyze audio
- **Key Features**:
  - Audio recording controls
  - Real-time analysis
  - Session management

## 2. Daily Analysis Tab
- **View**: `DailySummaryView`
- **Icon**: Bar Chart (systemImage: "chart.bar") - *Note: This is just the tab icon, the view itself uses statistic boxes*
- **Purpose**: Shows daily behavior analysis and statistics
- **Key Features**:
  - Three colored statistic boxes showing counts:
    - Multipliers (green box with up arrow icon)
    - Diminishers (red box with down arrow icon)
    - Accidental Diminishers (orange box with exclamation icon)
  - Additional statistics displayed as rows:
    - Total Behaviors count
    - Sessions Analyzed count
    - Dominant Type
    - Net Tilt (M/D/AD breakdown)
  - Key Insights section with bullet points
  - Expandable Raw Analysis section
  - Date selection with calendar picker

## 3. Sessions Tab
- **View**: `SessionsListView`
- **Icon**: Bullet List (systemImage: "list.bullet")
- **Purpose**: Manages and displays all recording sessions
- **Key Features**:
  - List of all recording sessions
  - Session playback
  - Session editing
  - Session management

## Implementation Details
The tab structure is implemented using SwiftUI's `TabView` component in `MainTabView` (MacAudioRecorderApp.swift). The tabs share state through a common `activeSession` binding, allowing seamless interaction between different views.

### Code Structure
```swift
struct MainTabView: View {
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
```
