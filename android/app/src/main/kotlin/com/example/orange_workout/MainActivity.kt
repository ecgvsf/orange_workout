package com.example.orange_workout 

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.orangeworkout/live_timer"
    private val NOTIFICATION_ID = 200
    private val CHANNEL_ID = "rest_timer_chip_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startChipTimer" -> {
                    val seconds = call.argument("seconds") ?: 90
                    val exerciseName = call.argument("exerciseName") ?: "Recupero"
                    startChipNotification(seconds, exerciseName)
                    result.success(true)
                }
                "stopChipTimer" -> {
                    stopChipNotification()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Timer Recupero Pillola",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Mostra la pillola e il timer continuo"
                setSound(null, null)
                enableVibration(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startChipNotification(seconds: Int, exerciseName: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Calcola il target temporale assoluto per il cronometro nativo
        val stopTimeMillis = SystemClock.elapsedRealtime() + (seconds * 1000L)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.logo_monochromatic) // Il tuo drawable monocromatico
            .setContentTitle("Recupero • $exerciseName")
            .setContentText("Timer in corso")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // QUESTI 4 ATTRIBUTI ATTIVANO LA PILLOLA NELLA STATUS BAR
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(System.currentTimeMillis() + (seconds * 1000L))

        // Su Android 12+ questo attiva specificamente la pillola per le Ongoing Activities
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        }

        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun stopChipNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }
}