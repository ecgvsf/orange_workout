import 'dart:io';
import 'package:flutter/services.dart';

class NativeTimerChipService {
  static const MethodChannel _channel = MethodChannel(
    'com.orangeworkout/live_timer',
  );

  static Future start({
    required int seconds,
    required String exerciseName,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startChipTimer', {
        'seconds': seconds,
        'exerciseName': exerciseName,
      });
    } catch (e) {
      print('Errore start chip timer: $e');
    }
  }

  static Future stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopChipTimer');
    } catch (e) {
      print('Errore stop chip timer: $e');
    }
  }
}
