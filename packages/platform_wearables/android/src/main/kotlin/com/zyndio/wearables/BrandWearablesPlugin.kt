package com.zyndio.wearables

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel

/**
 * Health Connect / OAuth native support has not shipped for Android yet; every
 * method call responds with UNAVAILABLE until a real implementation lands.
 */
class BrandWearablesPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var activity: Activity? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "platform_wearables")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "platform_wearables/events")
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "requestHealthPermissions",
      "getSleepSessions",
      "getHeartRate",
      "getHRV",
      "getSpO2",
      "getActivity",
      "getWorkouts",
      "getBodyMeasurements",
      "getGlucose",
      "startOAuthFlow" -> {
        result.error(
          "UNAVAILABLE",
          "${call.method} is not available on Android in this build",
          null
        )
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}
