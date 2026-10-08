package com.example.orange_workout

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent // <-- Aggiungi questa riga
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.orange_workout/dynamic_island"
    private val NOTIFICATION_ID = 999
    private val SUMMARY_NOTIFICATION_ID = 1000
    private var methodChannel: MethodChannel? = null

    // Ascolta i comandi provenienti dalla Dynamic Island e li gira a Flutter
    private val islandActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "ADD_TIME_FROM_ISLAND") {
                val addedSecs = intent.getIntExtra("seconds", 0)
                methodChannel?.invokeMethod("addTime", addedSecs)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(islandActionReceiver, IntentFilter("ADD_TIME_FROM_ISLAND"), RECEIVER_EXPORTED)
        } else {
            registerReceiver(islandActionReceiver, IntentFilter("ADD_TIME_FROM_ISLAND"))
        }

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "startSilentNotification" -> {
                    val exercise = call.argument<String>("exerciseName") ?: "Recupero"
                    showSilentNotification(exercise)
                    result.success(true)
                }
                "stopSilentNotification" -> {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.cancel(NOTIFICATION_ID)
                    result.success(true)
                }
                "showIsland" -> {
                    val seconds = call.argument<Int>("seconds") ?: 180
                    val intent = Intent("SHOW_ISLAND_ACTION")
                    intent.putExtra("seconds", seconds)
                    sendBroadcast(intent)
                    result.success(true)
                }
                "hideIsland" -> {
                    sendBroadcast(Intent("HIDE_ISLAND_ACTION"))
                    result.success(true)
                }
                "showEndRestNotification" -> {
                    val title = call.argument<String>("title") ?: "Tempo Scaduto!"
                    val body = call.argument<String>("body") ?: "Inizia la prossima Serie."
                    showEndRestNotification(title, body)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showSilentNotification(exercise: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "silent_island_channel_v2"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // IMPORTANCE_LOW impedisce il popup a discesa (Heads-up)
            val channel = NotificationChannel(channelId, "Timer Silenzioso", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val iconRes = resources.getIdentifier("launcher_icon", "mipmap", packageName)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle("Recupero in corso")
            .setContentText(exercise)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true) // Impedisce lo swipe

        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun showEndRestNotification(title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "workout_end_rest_summary_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // IMPORTANCE_HIGH per far scendere il banner
            val channel = NotificationChannel(channelId, "Recupero Terminato", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        }

        val iconRes = resources.getIdentifier("launcher_icon", "mipmap", packageName)

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingIntentFlags)

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true) // Scompare quando ci clicchi
            .setContentIntent(pendingIntent)

        manager.notify(SUMMARY_NOTIFICATION_ID, builder.build())
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, DynamicIslandAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) return true
        }
        return false
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(islandActionReceiver)
    }
}
