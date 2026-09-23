import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class WorkoutNotificationService {
  static final WorkoutNotificationService _instance =
      WorkoutNotificationService._internal();
  factory WorkoutNotificationService() => _instance;
  WorkoutNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Inizializza il plugin e registra i canali audio/vibrazione nativi
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    final androidImpl =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidImpl?.requestNotificationsPermission();

    // 1. CANALE SILENZIOSO PER IL TIMER (Non fa scendere il popup heads-up!)
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'workout_rest_silent_v1', // ID nuovo dedicato al timer discreto
        'Timer Recupero (Discreto)',
        description: 'Mostra il cronometro senza banner fluttuanti',
        importance: Importance.low, // 👈 LOW = NESSUN BANNER A DISCESA!
        enableVibration: false,
        playSound: false,
        showBadge: false,
      ),
    );

    // 2. CANALE AD ALTA PRIORITÀ PER LA FINE DEL RECUPERO (Allarme + Vibrazione)
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'workout_rest_alarm_v3',
        'Avviso Fine Recupero (Allarme)',
        description: 'Avviso con suono/vibrazione quando il tempo è a zero',
        importance:
            Importance.max, // 👈 MAX = Suona, vibra e si illumina a fine tempo
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );
  }

  /// Avvia il conto alla rovescia e pianifica la notifica di completamento
  Future<void> startRestNotification({
    required int seconds,
    required String exerciseName,
  }) async {
    await cancelRestNotifications();

    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    // 1. CHRONOMETER COUNTDOWN LIVE SU SCHERMATA DI BLOCCO (Android)
    if (Platform.isAndroid) {
      final targetTimeMillis =
          DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;

      final liveDetails = AndroidNotificationDetails(
        'workout_rest_silent_v1', // 👈 Usa il canale discreto
        'Timer Recupero (Discreto)',
        channelDescription: 'Visualizza il tempo di recupero residuo',
        icon: '@drawable/notification_logo',
        largeIcon: const DrawableResourceAndroidBitmap(
          '@drawable/notification_logo',
        ),

        // 👇 QUESTE DUE RIGHE BLOCCANO IL POPUP IN ALTO:
        importance: Importance.low,
        priority: Priority.low,

        // Rende comunque la notifica visibile sulla Lock Screen e non eliminabile con swipe:
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,

        showWhen: true,
        when: targetTimeMillis,
        usesChronometer: true,
        chronometerCountDown: true,
        category: AndroidNotificationCategory.stopwatch,
        timeoutAfter: seconds * 1000,
      );

      await _plugin.show(
        100,
        'Recupero in corso ⏱️',
        'Prossimo: $exerciseName',
        NotificationDetails(android: liveDetails),
      );
    }

    // 2. AVVISO FINALE A TEMPO SCADUTO (Android & iOS)
    final androidFinalDetails = AndroidNotificationDetails(
      'workout_rest_channel',
      'Timer Recupero Workout',
      icon: '@drawable/notification_logo',
      largeIcon: const DrawableResourceAndroidBitmap(
        '@drawable/notification_logo',
      ),
      channelDescription: 'Avviso fine riposo serie',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );

    const iosFinalDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // Verifica se Android consente gli allarmi esatti per evitare PlatformException
    AndroidScheduleMode scheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      final androidImpl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final bool? canScheduleExact =
          await androidImpl?.canScheduleExactNotifications();
      if (canScheduleExact == true) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    try {
      await _plugin.zonedSchedule(
        101,
        'Tempo Scaduto! ⏱️',
        'È ora di iniziare la serie di $exerciseName',
        scheduledDate,
        NotificationDetails(android: androidFinalDetails, iOS: iosFinalDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Fallback nel caso in cui il dispositivo blocchi la schedulazione esatta
      await _plugin.zonedSchedule(
        101,
        'Tempo Scaduto! ⏱️',
        'È ora di iniziare la serie di $exerciseName',
        scheduledDate,
        NotificationDetails(android: androidFinalDetails, iOS: iosFinalDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancella sia il cronometro sia l'avviso acustico pendente
  Future<void> cancelRestNotifications() async {
    await _plugin.cancel(100);
    await _plugin.cancel(101);
  }
}
