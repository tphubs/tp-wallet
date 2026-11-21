package com.tphubs.tp_wallet

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "tp_wallet/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(isListenerEnabled())
                "openPermissionSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                "drainQueue" -> result.success(BankNotificationService.drain(applicationContext))
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "tp_wallet/notification_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    BankNotificationService.listener = { events.success(null) }
                }

                override fun onCancel(arguments: Any?) {
                    BankNotificationService.listener = null
                }
            }
        )
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        return flat.split(":").any { it.startsWith("$packageName/") }
    }
}
