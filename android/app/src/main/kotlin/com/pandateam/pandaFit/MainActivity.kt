package com.pandateam.pandaFit

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Enable edge-to-edge mode for Android 15+ compatibility
        // This prevents deprecated setStatusBarColor/setNavigationBarColor warnings
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // For Android 15+, explicitly disable system bar contrasts
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
        }
    }
}
