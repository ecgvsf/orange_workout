import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct WorkoutRestLiveActivity: Widget {
    // Colori e stili dell'interfaccia
    private let brandOrange = Color(red: 1.0, green: 0.59, blue: 0.0)
    private let surfaceDark = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // ==========================================
            // 1. VISTA SCHERMATA DI BLOCCO / STANDBY
            // ==========================================
            let endDate = Date(timeIntervalSince1970: TimeInterval(context.state.endTime) / 1000.0)

            VStack(spacing: 12) {
                // Header: Badge + Esercizio Corrente
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(brandOrange)
                        Text(context.state.exerciseName.uppercased())
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("RECUPERO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(brandOrange.opacity(0.18))
                        .foregroundColor(brandOrange)
                        .clipShape(Capsule())
                }

                // Corpo centrale: Timer ad alto contrasto
                HStack(alignment: .lastTextBaseline) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(brandOrange)
                        
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Controlli Interattivi +15s e +30s
                    if #available(iOS 17.0, *) {
                        HStack(spacing: 8) {
                            Button(intent: AddRestTimeIntent(extraSeconds: 15)) {
                                Text("+15s")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 34)
                                    .background(surfaceDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(intent: AddRestTimeIntent(extraSeconds: 30)) {
                                Text("+30s")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 34)
                                    .background(surfaceDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.black)
            .activityBackgroundTint(Color.black)

        } dynamicIsland: { context in
            // ==========================================
            // 2. VISTA DYNAMIC ISLAND (iPhone 14 Pro+)
            // ==========================================
            let endDate = Date(timeIntervalSince1970: TimeInterval(context.state.endTime) / 1000.0)

            return DynamicIsland {
                // REGIONE ESPANSA (Pressione prolungata dell'Isola)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(context.state.exerciseName, systemImage: "figure.strengthtraining.traditional")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("Recupero attivo")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(brandOrange)
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if #available(iOS 17.0, *) {
                        HStack(spacing: 12) {
                            Button(intent: AddRestTimeIntent(extraSeconds: 15)) {
                                Label("+15s", systemImage: "plus")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(surfaceDark)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(intent: AddRestTimeIntent(extraSeconds: 30)) {
                                Label("+30s", systemImage: "plus")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(surfaceDark)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                }

            } compactLeading: {
                // REGIONE COMPATTA SINISTRA (Pillola a riposo)
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(brandOrange)
                    .padding(.leading, 3)

            } compactTrailing: {
                // REGIONE COMPATTA DESTRA (Timer compatto)
                Text(timerInterval: Date()...endDate, countsDown: true)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(brandOrange)
                    .frame(minWidth: 40)
                    .padding(.trailing, 3)

            } minimal: {
                // STATO MINIMALE (Quando ci sono due Live Activity concorrenti)
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(brandOrange)
            }
        }
    }
}