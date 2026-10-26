import ActivityKit
import WidgetKit
import SwiftUI

struct BrandAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the activity
        var status: String?
        var progress: String? // "0.0" to "1.0"
        var score: String?
        var window: String?
    }

    // Static data defined when activity starts
    var type: String // "lens", "timer", "rhythm"
    var title: String
    var emoji: String
    var endTime: String? // Timestamp string
}

@main
struct BrandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrandAttributes.self) { context in
            // Lock Screen / Banner UI
            BrandActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View (Long press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Text(context.attributes.emoji)
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text(context.attributes.title)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.attributes.type == "timer", let endTime = context.attributes.endTime {
                        let date = Date(timeIntervalSince1970: Double(endTime)! / 1000)
                        Text(date, style: .timer)
                            .font(.title2.monospacedDigit())
                            .foregroundColor(.blue)
                    } else if context.attributes.type == "rhythm", let score = context.state.score {
                        Text("\(score)%")
                            .font(.title2.bold())
                            .foregroundColor(.cyan)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if context.attributes.type == "lens" {
                            if let status = context.state.status {
                                Text(status)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            if let progressStr = context.state.progress, let progress = Double(progressStr) {
                                ProgressView(value: progress)
                                    .tint(.blue)
                            }
                        } else if context.attributes.type == "rhythm" {
                            if let window = context.state.window {
                                Text("Next Golden Window: \(window)")
                                    .font(.subheadline)
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text(context.attributes.emoji)
            } compactTrailing: {
                if context.attributes.type == "timer", let endTime = context.attributes.endTime {
                    let date = Date(timeIntervalSince1970: Double(endTime)! / 1000)
                    Text(date, style: .timer)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.blue)
                } else if context.attributes.type == "lens", let progressStr = context.state.progress, let progress = Double(progressStr) {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                } else if context.attributes.type == "rhythm", let score = context.state.score {
                    Text("\(score)%")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                }
            } minimal: {
                Text(context.attributes.emoji)
            }
        }
    }
}

struct BrandActivityView: View {
    let context: ActivityViewContext<BrandAttributes>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(context.attributes.emoji)
                    Text(context.attributes.title)
                        .font(.headline)
                }
                
                if let status = context.state.status {
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if context.attributes.type == "timer", let endTime = context.attributes.endTime {
                let date = Date(timeIntervalSince1970: Double(endTime)! / 1000)
                Text(date, style: .timer)
                    .font(.title.monospacedDigit())
                    .foregroundColor(.blue)
            } else if context.attributes.type == "rhythm", let score = context.state.score {
                VStack {
                    Text("\(score)%")
                        .font(.title2.bold())
                    Text("RHYTHM")
                        .font(.caption2)
                }
                .foregroundColor(.cyan)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}
