package com.alozair.my_nots

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.alozair.my_nots/native"
    private var launchAction: String? = null

    companion object {
        const val ACTION_QUICK_NOTE = "com.alozair.my_nots.QUICK_NOTE"
        const val ACTION_NEW_NOTE = "com.alozair.my_nots.NEW_NOTE"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchAction(intent)
    }

    private fun captureLaunchAction(intent: Intent?) {
        launchAction = when (intent?.action) {
            ACTION_QUICK_NOTE -> "quick_note"
            ACTION_NEW_NOTE -> "new_note"
            else -> intent?.getStringExtra("launch_action")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "toggleFloatingNote" -> {
                    if (checkOverlayPermission()) {
                        val intent = Intent(this, FloatingNoteService::class.java)
                        startService(intent)
                        result.success(null)
                    } else {
                        requestOverlayPermission()
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
                "updateWidget" -> {
                    val intent = Intent(this, NoteWidgetProvider::class.java)
                    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = AppWidgetManager.getInstance(application)
                        .getAppWidgetIds(ComponentName(application, NoteWidgetProvider::class.java))
                    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    sendBroadcast(intent)
                    result.success(null)
                }
                "getLaunchAction" -> {
                    result.success(launchAction)
                    launchAction = null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }
}
