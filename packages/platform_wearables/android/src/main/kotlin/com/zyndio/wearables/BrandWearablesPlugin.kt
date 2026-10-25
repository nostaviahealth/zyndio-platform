package com.zyndio.wearables

import android.app.Activity
import com.zyndio.core.BrandHealthConnectManager
import com.zyndio.core.BrandOAuthManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant

class BrandWearablesPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var healthManager: BrandHealthConnectManager? = null
  private val oauthManager = BrandOAuthManager()
  private var activity: Activity? = null
  private val scope = CoroutineScope(Dispatchers.IO)

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "platform_wearables")
    channel.setMethodCallHandler(this)

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "platform_wearables/events")
    
    healthManager = BrandHealthConnectManager(flutterPluginBinding.applicationContext)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val healthManager = this.healthManager ?: return result.error("INIT_FAILED", "HealthConnectManager not initialized", null)
    
    when (call.method) {
      "requestHealthPermissions" -> {
        // Mock permission request, should use the Activity result API in real app
        scope.launch {
          try {
            val granted = healthManager.hasAllPermissions()
            launch(Dispatchers.Main) { result.success(granted) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getSleepSessions" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getSleepSessions(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getHeartRate" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getHeartRate(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getHRV" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getHRV(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getSpO2" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getSpO2(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getActivity" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getActivity(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getWorkouts" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getWorkouts(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getBodyMeasurements" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getBodyMeasurements(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "getGlucose" -> {
        val start = call.argument<Long>("start") ?: 0
        val end = call.argument<Long>("end") ?: System.currentTimeMillis()
        scope.launch {
          try {
            val data = healthManager.getGlucose(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end))
            launch(Dispatchers.Main) { result.success(data.map { it.toMap() }) }
          } catch (e: Exception) {
            launch(Dispatchers.Main) { result.error("ERROR", e.message, null) }
          }
        }
      }
      "startOAuthFlow" -> {
        val authUrl = call.argument<String>("authUrl")
        val callbackScheme = call.argument<String>("callbackScheme")
        val act = activity
        if (authUrl != null && callbackScheme != null && act != null) {
          oauthManager.launchOAuthFlow(act, authUrl, callbackScheme)
          result.success("Launched")
        } else {
          result.error("ERROR", "Missing parameters or no Activity attached", null)
        }
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
