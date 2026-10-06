import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class WorkoutNotificationService {
  static final WorkoutNotificationService _instance =
      WorkoutNotificationService._internal();
  factory WorkoutNotificationService() => _instance;
  WorkoutNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Uint8List? _logoBytes;

  static final Int64List _alarmVibrationPattern = Int64List.fromList([
    0,
    1000,
    300,
    1000,
  ]);

  void Function(int extraSeconds)? onAddTimeListener;

  Future init() async {
    tz.initializeTimeZones();

    try {
      final byteData = await rootBundle.load('assets/images/logo2.png');
      _logoBytes = byteData.buffer.asUint8List();
    } catch (_) {
      _logoBytes = null;
    }

    const androidSettings = AndroidInitializationSettings(
      '@drawable/logo_monochromatic',
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

    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImpl != null) {
      try {
        await (androidImpl as dynamic).requestNotificationsPermission();
      } catch (_) {}

      // Manteniamo solo il canale per la sveglia di fine recupero
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'workout_rest_alarm_v3',
          'Avviso Fine Recupero (Allarme)',
          description: 'Vibrazione e suono quando il tempo scade',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: _alarmVibrationPattern,
          playSound: true,
          showBadge: true,
        ),
      );
    }
  }

  Future startRestNotification({
    required int seconds,
    required String exerciseName,
  }) async {
    await cancelRestNotifications();

    if (seconds <= 0) return;

    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    final ByteArrayAndroidBitmap? largeIconBitmap =
        _logoBytes != null ? ByteArrayAndroidBitmap(_logoBytes!) : null;

    // LA NOTIFICA "LIVE" PER ANDROID E' STATA RIMOSSA QUI.
    // VIENE ORA GESTITA IN KOTLIN PER LA DYNAMIC ISLAND.

    // Allarme di fine recupero (ID: 101) - Mantenuto per Android e iOS
    final androidFinalDetails = AndroidNotificationDetails(
      'workout_rest_alarm_v3',
      'Avviso Fine Recupero (Allarme)',
      channelDescription: 'Avviso fine riposo serie',
      icon: '@drawable/logo_monochromatic',
      largeIcon: largeIconBitmap,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _alarmVibrationPattern,
      category: AndroidNotificationCategory.alarm,
    );

    const iosFinalDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    AndroidScheduleMode scheduleMode =
        AndroidScheduleMode.inexactAllowWhileIdle;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      try {
        final bool? canScheduleExact =
            await (androidImpl as dynamic)?.canScheduleExactNotifications();
        if (canScheduleExact == true) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      } catch (_) {}
    }

    try {
      // Programma l'allarme che suonerà quando il tempo scade
      await _plugin.zonedSchedule(
        101,
        'Tempo Scaduto! ⏱️',
        'Inizia la prossima serie di $exerciseName',
        scheduledDate,
        NotificationDetails(android: androidFinalDetails, iOS: iosFinalDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future triggerInstantAlarm(String exerciseName) async {
    final ByteArrayAndroidBitmap? largeIconBitmap =
        _logoBytes != null ? ByteArrayAndroidBitmap(_logoBytes!) : null;

    final androidDetails = AndroidNotificationDetails(
      'workout_rest_alarm_v3',
      'Avviso Fine Recupero (Allarme)',
      channelDescription: 'Vibrazione istantanea fine recupero',
      icon: '@drawable/logo_monochromatic',
      largeIcon: largeIconBitmap,
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      vibrationPattern: _alarmVibrationPattern,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      102,
      'Tempo Scaduto! ⏱️',
      'Inizia la serie di $exerciseName',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future cancelRestNotifications() async {
    await _plugin.cancel(101); // Cancella l'allarme schedulato
    await _plugin.cancel(102); // Cancella l'allarme istantaneo (se presente)
  }
}
