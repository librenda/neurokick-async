I'll examine your codebase carefully to determine exactly where files are currently being saved.
Ran tool

Read file: MacAudioRecorder/ViewModels/TranscriptionViewModel.swift

Ran tool

Read file: MacAudioRecorder/Services/SessionManager.swift

Read file: MacAudioRecorder/ViewModels/TranscriptionViewModel.swift

Ran tool

Ran tool

Ran tool

Read file: MacAudioRecorder/ViewModels/DailyBehaviorAnalyzer.swift

Ran tool

Read file: MacAudioRecorder/ViewModels/DailyBehaviorAnalyzer.swift

Perfect! I've carefully examined your codebase to determine **exactly** where files are currently being saved. Here's the detailed breakdown:

## **📂 Current File Storage Locations**

### **❌ NOT USED: `~/Documents/NeuroKick_Results/`**
This directory was **planned but commented out**:

```swift
// MacAudioRecorder/ViewModels/TranscriptionViewModel.swift (lines 89-98)
/*
let neuroKickFolder = documentsPath.appendingPathComponent("NeuroKick_Results")

// Create NeuroKick_Results folder if it doesn't exist
do {
    try FileManager.default.createDirectory(at: neuroKickFolder, withIntermediateDirectories: true, attributes: nil)
} catch {
    print("❌ Failed to create NeuroKick_Results folder: \(error)")
    return
}
*/
```

**Status**: 🚫 **Commented out and not active**

### **✅ ACTIVELY USED: `~/Documents/NeuroKick_Sessions/`**
This is your **organized session storage** via `SessionManager`:

```swift
// MacAudioRecorder/Services/SessionManager.swift (line 18)
self.sessionsDirectory = documentsPath.appendingPathComponent("NeuroKick_Sessions")
```

**Structure:**
```
~/Documents/NeuroKick_Sessions/
├── [session-uuid-1]/
│   ├── recording.m4a
│   ├── transcript.txt
│   └── analysis.txt
├── [session-uuid-2]/
│   ├── recording.m4a
│   ├── transcript.txt
│   └── analysis.txt
└── [more sessions...]
```

**Used for**: SwiftData-managed sessions with proper organization

### **✅ ACTIVELY USED: `~/Documents/` (Direct)**
This is where **individual files** are saved:

#### **Auto-saved Files:**
```swift
// Audio recordings (AudioRecorder.swift lines 128-129)
~/Documents/mic_recording.m4a
~/Documents/system_audio_recording.m4a

// Transcripts (TranscriptionViewModel.swift line 87)
~/Documents/transcript-[sessionId].txt

// Analysis results (TranscriptionViewModel.swift line 139)
~/Documents/Workplace-[sessionId].txt
~/Documents/Summary-[sessionId].txt  
~/Documents/Behavioral-[sessionId].txt
```

#### **Manual Save Files:**
When you use "Save Transcript" or "Save Summary" buttons, they use `NSSavePanel` so files go **wherever the user chooses**.

#### **Daily Analysis Files:**
```swift
// DailyBehaviorAnalyzer.swift looks for files like:
~/Documents/Behavioral-2025-01-17-[timestamp].txt
```

**Used for**: Individual analysis files that DailyBehaviorAnalyzer aggregates

## **🔍 Summary of Active File Locations**

| **File Type** | **Location** | **Purpose** | **Active?** |
|---|---|---|---|
| **Session Audio** | `~/Documents/NeuroKick_Sessions/[uuid]/recording.m4a` | Organized session storage | ✅ **YES** |
| **Session Transcripts** | `~/Documents/NeuroKick_Sessions/[uuid]/transcript.txt` | Organized session storage | ✅ **YES** |
| **Session Analysis** | `~/Documents/NeuroKick_Sessions/[uuid]/analysis.txt` | Organized session storage | ✅ **YES** |
| **Individual Audio** | `~/Documents/mic_recording.m4a` | Simple recording mode | ✅ **YES** |
| **Individual Audio** | `~/Documents/system_audio_recording.m4a` | Simple recording mode | ✅ **YES** |
| **Individual Transcripts** | `~/Documents/transcript-[id].txt` | Auto-saved transcripts | ✅ **YES** |
| **Individual Analysis** | `~/Documents/Workplace-[id].txt` | Auto-saved analysis | ✅ **YES** |
| **Daily Aggregation** | `~/Documents/Behavioral-[date]-[time].txt` | Daily analysis input | ✅ **YES** |
| **User Manual Saves** | User-selected locations | Manual save dialogs | ✅ **YES** |
| **NeuroKick_Results** | `~/Documents/NeuroKick_Results/` | **Commented out** | ❌ **NO** |

## **🎯 Current Active Workflow**

1. **Simple Recording** → Files go to `~/Documents/` directly
2. **Session Recording** → Files go to `~/Documents/NeuroKick_Sessions/[uuid]/`
3. **Manual Saves** → User chooses location via save dialog
4. **Daily Analysis** → Reads from `~/Documents/` and aggregates behavior files

## **📊 What This Means**

- **Your organized session system is working** ✅
- **Your simple recording system saves to Documents root** ✅
- **NeuroKick_Results was planned but never implemented** ❌
- **You have a hybrid system**: Sessions go to organized folders, individual files go to Documents root

The current approach gives you **both** organized session management AND simple file access - which is actually quite good! 🎉