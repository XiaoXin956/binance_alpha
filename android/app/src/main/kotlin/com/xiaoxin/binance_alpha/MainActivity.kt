package com.xiaoxin.binance_alpha

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.xiaoxin.binance_alpha/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val jsonData = call.argument<String>("data")
                    if (jsonData != null) {
                        AppWidgetProvider.updateFromApp(this, jsonData)
                        result.success(true)
                    } else {
                        result.error("NO_DATA", "No data provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
