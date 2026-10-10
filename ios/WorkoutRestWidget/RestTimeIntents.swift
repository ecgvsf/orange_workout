import AppIntents
import ActivityKit
import Foundation

// 1. Modello Dati compatibile con il plugin live_activities
public struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        public var endTime: Int          // Timestamp millisecondi
        public var exerciseName: String // Esercizio corrente
        public var totalDuration: Int   // Durata originale per calcolare percentuali
        
        public init(endTime: Int, exerciseName: String, totalDuration: Int = 90) {
            self.endTime = endTime
            self.exerciseName = exerciseName
            self.totalDuration = totalDuration
        }
    }

    public var id = UUID()
}

// 2. Intent interattivo per aggiungere tempo (+15s / +30s)
@available(iOS 17.0, *)
struct AddRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Aggiungi Tempo Recupero"
    
    @Parameter(title: "Secondi da aggiungere")
    var extraSeconds: Int

    init() {}

    init(extraSeconds: Int) {
        self.extraSeconds = extraSeconds
    }

    func perform() async throws -> some IntentResult {
        // Recupera l'attività Live attiva
        guard let activity = Activity<LiveActivitiesAppAttributes>.activities.first else {
            return .result()
        }

        let currentEndTime = activity.content.state.endTime
        let newEndTime = currentEndTime + (extraSeconds * 1000)
        let updatedState = LiveActivitiesAppAttributes.ContentState(
            endTime: newEndTime,
            exerciseName: activity.content.state.exerciseName,
            totalDuration: activity.content.state.totalDuration + extraSeconds
        )

        // Aggiorna istantaneamente la Live Activity e la Dynamic Island in background
        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )

        // Salva l'estensione negli UserDefaults condivisi per sincronizzare Flutter al rientro
        if let sharedDefaults = UserDefaults(suiteName: "group.com.example.orangeWorkout") {
            sharedDefaults.set(newEndTime, forKey: "rest_end_timestamp")
        }

        return .result()
    }
}