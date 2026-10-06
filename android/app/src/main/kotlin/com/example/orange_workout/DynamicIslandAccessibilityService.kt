package com.example.orange_workout

import android.accessibilityservice.AccessibilityService
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import androidx.annotation.RequiresApi
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import kotlinx.coroutines.delay

// STATO GLOBALE DEL TIMER
var globalTimeRemaining = mutableStateOf(0)
var globalIsRunning = mutableStateOf(false)

@RequiresApi(Build.VERSION_CODES.P)
class DynamicIslandAccessibilityService : AccessibilityService() {

    private lateinit var windowManager: WindowManager
    private var composeView: ComposeView? = null
    private lateinit var lifecycleOwner: ServiceLifecycleOwner
    private var isViewAdded = false
    private val isExpandedState = mutableStateOf(false)

    // Ricevitore per i comandi in arrivo da Flutter (tramite MainActivity)
    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "SHOW_ISLAND_ACTION" -> {
                    val secs = intent.getIntExtra("seconds", 180)
                    globalTimeRemaining.value = secs
                    globalIsRunning.value = true
                    showIsland()
                }
                "HIDE_ISLAND_ACTION" -> {
                    globalIsRunning.value = false
                    hideIsland()
                }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        lifecycleOwner = ServiceLifecycleOwner()
        lifecycleOwner.performRestore(null)
        lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        
        // Registra l'ascoltatore per i comandi di MainActivity
        registerReceiver(commandReceiver, IntentFilter().apply {
            addAction("SHOW_ISLAND_ACTION")
            addAction("HIDE_ISLAND_ACTION")
        }, RECEIVER_EXPORTED)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            composeView?.visibility = View.GONE
            isExpandedState.value = false
        } else if (newConfig.orientation == Configuration.ORIENTATION_PORTRAIT) {
            composeView?.visibility = View.VISIBLE
        }
    }

    private fun showIsland() {
        if (isViewAdded) return
        isExpandedState.value = false

        composeView = ComposeView(this).apply {
            setContent {
                DynamicIslandOverlay(
                    isExpanded = isExpandedState.value,
                    onExpandedChange = { isExpandedState.value = it },
                    onClose = { hideIslandAndNotification() }
                )
            }
            setOnTouchListener { _, event ->
                if (event.action == MotionEvent.ACTION_OUTSIDE) {
                    if (isExpandedState.value) isExpandedState.value = false
                    return@setOnTouchListener true
                }
                false
            }
        }

        composeView?.setViewTreeLifecycleOwner(lifecycleOwner)
        composeView?.setViewTreeSavedStateRegistryOwner(lifecycleOwner)
        composeView?.setViewTreeViewModelStoreOwner(lifecycleOwner)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
        }

        try {
            windowManager.addView(composeView, params)
            isViewAdded = true
        } catch (e: Exception) {
            Log.e("DynamicIsland", "Errore aggiunta vista", e)
        }
    }

    private fun hideIsland() {
        if (isViewAdded && composeView != null) {
            windowManager.removeView(composeView)
            isViewAdded = false
        }
    }
    
    // Ferma la pillola E chiude la notifica silenziosa
    private fun hideIslandAndNotification() {
        hideIsland()
        globalIsRunning.value = false
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(999) 
    }

    override fun onDestroy() {
        super.onDestroy()
        hideIsland()
        unregisterReceiver(commandReceiver)
        lifecycleOwner.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}
}

@RequiresApi(Build.VERSION_CODES.P)
@Composable
fun DynamicIslandOverlay(
    isExpanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val density = LocalDensity.current

    // Sincronizzazione con lo stato globale
    var timeRemaining by globalTimeRemaining
    val isRunning by globalIsRunning

    // Scorrimento del tempo
    LaunchedEffect(isRunning, timeRemaining) {
        if (isRunning && timeRemaining > 0) {
            delay(1000)
            timeRemaining--
            if (timeRemaining <= 0) {
                onClose() // Chiude automaticamente a zero
            }
        }
    }

    var cutoutRect by remember { mutableStateOf(Rect(0, 0, 0, 0)) }
    val view = androidx.compose.ui.platform.LocalView.current

    DisposableEffect(view) {
        val listener = View.OnApplyWindowInsetsListener { _, insets ->
            val cutout = insets.displayCutout
            if (cutout != null && cutout.boundingRects.isNotEmpty()) {
                val topCutout = cutout.boundingRects.firstOrNull { it.top <= 150 } ?: cutout.boundingRects.first()
                cutoutRect = topCutout
            }
            insets
        }
        view.setOnApplyWindowInsetsListener(listener)
        onDispose { view.setOnApplyWindowInsetsListener(null) }
    }

    val hasCutout = cutoutRect.width() > 0
    val systemNotchHeight = if (hasCutout) with(density) { cutoutRect.height().toDp() } else 35.dp
    val notchHeightDp = (systemNotchHeight - 8.dp).coerceAtLeast(24.dp)
    val notchWidthDp = if (hasCutout) with(density) { (cutoutRect.width() * 0.85f).toDp() } else 70.dp
    val notchTopDp = if (hasCutout) with(density) { cutoutRect.top.toDp() } else 0.dp

    val collapsedSideWidth = 50.dp
    val collapsedWidth = notchWidthDp + (collapsedSideWidth * 2)
    val expandedWidth = 320.dp
    val expandedHeight = 160.dp
    val safeTopMargin = (notchTopDp + 4.dp).coerceAtLeast(0.dp)

    val animatedWidth by animateDpAsState(
        targetValue = if (isExpanded) expandedWidth else collapsedWidth,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "width"
    )
    val animatedHeight by animateDpAsState(
        targetValue = if (isExpanded) expandedHeight else notchHeightDp,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "height"
    )
    val animatedCorner by animateDpAsState(targetValue = if (isExpanded) 32.dp else 50.dp, label = "corner")

    LaunchedEffect(animatedWidth, animatedHeight, safeTopMargin) {
        view.requestLayout()
        try {
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val rootView = view.rootView
            val params = rootView.layoutParams as? WindowManager.LayoutParams
            if (params != null) windowManager.updateViewLayout(rootView, params)
        } catch (e: Exception) {}
    }

    Box(
        modifier = Modifier.fillMaxWidth().wrapContentHeight().padding(top = safeTopMargin, bottom = 32.dp),
        contentAlignment = Alignment.TopCenter
    ) {
        Box(
            modifier = Modifier
                .offset(x = 12.dp)
                .width(animatedWidth)
                .height(animatedHeight)
                .pointerInput(Unit) { detectTapGestures(onTap = { onExpandedChange(!isExpanded) }) }
                .background(Color.Black, shape = RoundedCornerShape(animatedCorner))
        ) {
            // STATO COLLASSATO
            AnimatedVisibility(visible = !isExpanded, enter = fadeIn(tween(300, delayMillis = 300)), exit = fadeOut(tween(100))) {
                Row(modifier = Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                    Box(modifier = Modifier.width(collapsedSideWidth), contentAlignment = Alignment.Center) {
                        Icon(painter = painterResource(id = R.drawable.logo_monochromatic), contentDescription = null, tint = Color.White, modifier = Modifier.offset(x = (-4).dp).size(notchHeightDp * 0.45f))
                    }
                    Spacer(modifier = Modifier.width(notchWidthDp))
                    Box(modifier = Modifier.width(collapsedSideWidth), contentAlignment = Alignment.Center) {
                        Text(text = formatTime(timeRemaining), color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.offset(x = (-6).dp))
                    }
                }
            }

            // STATO ESPANSO (+15, +30)
            AnimatedVisibility(visible = isExpanded, enter = fadeIn(tween(400, delayMillis = 150)), exit = fadeOut(tween(100))) {
                Column(modifier = Modifier.fillMaxSize().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.SpaceBetween) {
                    Text(" ", color = Color.Gray, fontSize = 14.sp)
                    Text(text = formatTime(timeRemaining), color = Color.White, fontSize = 48.sp, fontWeight = FontWeight.Bold)
                                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                        Button(onClick = { onClose() }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF4600))) { Text("Elimina") }
                        Button(onClick = { 
                            timeRemaining += 15 
                            context.sendBroadcast(Intent("ADD_TIME_FROM_ISLAND").putExtra("seconds", 15))
                        }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE78800))) { Text("+15s") }
                        Button(onClick = { 
                            timeRemaining += 30 
                            context.sendBroadcast(Intent("ADD_TIME_FROM_ISLAND").putExtra("seconds", 30))
                        }, colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE78800))) { Text("+30s") }
                    }

                }
            }
        }
    }
}

fun formatTime(seconds: Int): String {
    val m = (seconds / 60).toString().padStart(2, '0')
    val s = (seconds % 60).toString().padStart(2, '0')
    return "$m:$s"
}

class ServiceLifecycleOwner : androidx.savedstate.SavedStateRegistryOwner, androidx.lifecycle.ViewModelStoreOwner {
    private var mLifecycleRegistry = androidx.lifecycle.LifecycleRegistry(this)
    private var mSavedStateRegistryController = androidx.savedstate.SavedStateRegistryController.create(this)
    private val store = androidx.lifecycle.ViewModelStore()
    override val lifecycle get() = mLifecycleRegistry
    override val savedStateRegistry get() = mSavedStateRegistryController.savedStateRegistry
    override val viewModelStore get() = store
    fun handleLifecycleEvent(event: androidx.lifecycle.Lifecycle.Event) { mLifecycleRegistry.handleLifecycleEvent(event) }
    fun performRestore(savedState: android.os.Bundle?) { mSavedStateRegistryController.performRestore(savedState) }
}