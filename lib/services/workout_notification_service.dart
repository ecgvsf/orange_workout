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

      // 1. CANALE DEDICATO ALLA PILLOLA / FOREGROUND
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'workout_rest_fgs_v5', // ID nuovo per forzare il refresh delle impostazioni
          'Timer Recupero (Pillola e Barra)',
          description:
              'Gestisce il cronometro continuo e la pillola in barra di stato',
          importance: Importance.max, // Indispensabile per attivare il chip
          enableVibration: false,
          playSound: false,
          showBadge: false,
        ),
      );

      // 2. CANALE SVEGLIA FINE RECUPERO
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

    if (Platform.isAndroid) {
      final targetTimeMillis =
          DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;

      final liveDetails = AndroidNotificationDetails(
        'workout_rest_fgs_v5',
        'Timer Recupero (Pillola e Barra)',
        channelDescription: 'Visualizza il tempo di recupero residuo',
        icon: '@drawable/logo_monochromatic',
        largeIcon: largeIconBitmap,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        when: targetTimeMillis,
        usesChronometer: true,
        chronometerCountDown: true,
        category: AndroidNotificationCategory.stopwatch,
        onlyAlertOnce: true,
        timeoutAfter: seconds * 1000,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImpl != null) {
        try {
          await androidImpl.startForegroundService(
            100,
            'Recupero • $exerciseName',
            'Tempo rimanente',
            notificationDetails: liveDetails,
          );
        } catch (_) {
          await _plugin.show(
            100,
            'Recupero • $exerciseName',
            'Tempo rimanente',
            NotificationDetails(android: liveDetails),
          );
        }
      }
    }

    // 2. Allarme di fine recupero (ID: 101)
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
    await _plugin.cancel(100);
    await _plugin.cancel(101);

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      try {
        await (androidImpl as dynamic)?.stopForegroundService();
      } catch (_) {}
    }
  }
}
