import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutRestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
    }
    var exerciseName: String
}

struct WorkoutRestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestAttributes.self) { context in
            // VISTA SU SCHERMATA DI BLOCCO
            HStack {
                VStack(alignment: .leading) {
                    Text(context.attributes.exerciseName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Recupero in corso")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
                // Testo nativo Apple che fa il count down in tempo reale da solo:
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .padding()
            .activityBackgroundTint(Color.black)
        } dynamicIsland: { context in
            // VISTA DYNAMIC ISLAND (per iPhone 14 Pro e successivi)
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.exerciseName).font(.caption).foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundColor(.orange)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .frame(width: 45)
            } minimal: {
                Image(systemName: "timer").foregroundColor(.orange)
            }
        }
    }
}