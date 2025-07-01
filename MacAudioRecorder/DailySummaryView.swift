import SwiftUI

@available(macOS 12.0, *)
struct DailySummaryView: View {
    // State for daily behavior analysis
    @StateObject private var dailyAnalyzer = DailyBehaviorAnalyzer()
    @State private var selectedDate = Date()
    @Environment(\.scenePhase) private var scenePhase
    // State for UI controls
    @State private var showRawAnalysis = false
    
    private func cleanup() {
        // Cancel any ongoing analysis
        dailyAnalyzer.cancelAnalysis()
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Daily Behavior Analysis")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            
            if dailyAnalyzer.isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .controlSize(.small)
                    Text("Analyzing behaviors...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    private var dateSelectionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Select Date", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                DatePicker("Date:", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .frame(width: 160)
                    .labelsHidden()
                
                Spacer()
                
                Button(action: {
                    Task {
                        await dailyAnalyzer.analyzeBehaviors(for: selectedDate)
                    }
                }) {
                    Label("Analyze Day", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(dailyAnalyzer.isAnalyzing)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var analysisSummarySection: some View {
        VStack(spacing: 16) {
            // Statistics Grid
            HStack(spacing: 20) {
                // Multipliers (Green)
                StatisticBox(
                    title: "Multipliers",
                    count: dailyAnalyzer.summary?.multiplyingCount ?? 0,
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                // Diminishers (Red)
                StatisticBox(
                    title: "Diminishers",
                    count: dailyAnalyzer.summary?.diminishingCount ?? 0,
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
                
                // Accidental Diminishers (Orange)
                StatisticBox(
                    title: "Accidental",
                    count: dailyAnalyzer.summary?.accidentallyDiminishingCount ?? 0,
                    color: .orange,
                    icon: "exclamationmark.circle.fill"
                )
            }
            .padding(.vertical)
            
            // Additional Statistics
            if let summary = dailyAnalyzer.summary {
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(title: "Total Behaviors", value: "\(summary.totalCount)")
                    StatRow(title: "Sessions Analyzed", value: "\(summary.sessionsAnalyzed)")
                    StatRow(title: "Dominant Type", value: dailyAnalyzer.dominantBehaviorType)
                    StatRow(title: "Net Tilt", value: "M: \(summary.multiplyingCount), D: \(summary.diminishingCount), AD: \(summary.accidentallyDiminishingCount)")
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Key Insights
                if !summary.keyInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Insights")
                            .font(.headline)
                        
                        ForEach(summary.keyInsights, id: \.self) { insight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text(insight)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Raw Analysis Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showRawAnalysis.toggle() }) {
                        HStack {
                            Image(systemName: showRawAnalysis ? "chevron.down" : "chevron.right")
                            Text("Raw Analysis")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if showRawAnalysis {
                        Text(summary.rawAnalysisContent)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                dateSelectionSection
                
                if dailyAnalyzer.summary != nil {
                    analysisSummarySection
                } else if !dailyAnalyzer.statusMessage.isEmpty {
                    // Empty or Error State
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        
                        Text(dailyAnalyzer.statusMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.colorScheme, .light)
        .onDisappear {
            cleanup()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                cleanup()
            }
        }
    }
}

// MARK: - Supporting Views

@available(macOS 12.0, *)
private struct StatisticBox: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

@available(macOS 12.0, *)
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
} 