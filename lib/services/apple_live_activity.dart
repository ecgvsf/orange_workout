import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

class AppleLiveActivityService {
  static final _liveActivities = LiveActivities();

  static Future<void> init() async {
    if (!Platform.isIOS) return;
    await _liveActivities.init(appGroupId: 'group.com.example.orangeWorkout');
  }

  static Future<String?> startRestActivity({
    required String exerciseName,
    required int seconds,
  }) async {
    if (!Platform.isIOS) return null;

    final endTime = DateTime.now().add(Duration(seconds: seconds));
    final String activityId = 'rest_${DateTime.now().millisecondsSinceEpoch}';

    final Map<String, dynamic> activityData = {
      'exerciseName': exerciseName,
      'endTime': endTime.millisecondsSinceEpoch,
      'totalDuration': seconds,
    };

    try {
      return await _liveActivities.createActivity(
        activityId,
        activityData,
        removeWhenAppIsKilled: true,
        staleIn: Duration(seconds: seconds + 60),
      );
    } catch (e) {
      debugPrint("Errore creazione Live Activity: $e");
      return null;
    }
  }

  static Future<void> stopActivity(String activityId) async {
    if (!Platform.isIOS) return;
    try {
      await _liveActivities.endActivity(activityId);
    } catch (e) {
      debugPrint("Errore terminazione Live Activity: $e");
    }
  }
}