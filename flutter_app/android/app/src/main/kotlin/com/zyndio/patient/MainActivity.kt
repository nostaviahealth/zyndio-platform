package com.zyndio.patient

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val BRANDING_CHANNEL = "com.zyndio/branding"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Make status bar and navigation bar transparent
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        
        // Allow drawing in display cutout area (notch)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = 
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        // Set light/dark status bar icons
        WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BRANDING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlternateIconName" -> {
                    val iconName = call.argument<String>("iconName")
                    setAlternateIconName(iconName)
                    result.success(null)
                }
                "getAlternateIconName" -> {
                    result.success(getActiveIconName())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setAlternateIconName(iconName: String?) {
        val pm = packageManager
        val pkg = packageName
        
        // Match the activity-aliases defined in AndroidManifest.xml
        // Note: The package name passed to ComponentName must be the real package name from the Manifest
        val defaultAlias = ComponentName(pkg, "$pkg.MainActivityDefault")
        val plusAlias = ComponentName(pkg, "$pkg.MainActivityPlus")
        
        if (iconName == "PremiumBrand") {
            pm.setComponentEnabledSetting(plusAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(defaultAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        } else {
            pm.setComponentEnabledSetting(defaultAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(plusAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        }
    }

    private fun getActiveIconName(): String {
        val pm = packageManager
        val pkg = packageName
        val plusAlias = ComponentName(pkg, "$pkg.MainActivityPlus")
        
        val state = pm.getComponentEnabledSetting(plusAlias)
        return if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) "PremiumBrand" else "Default"
    }
}
