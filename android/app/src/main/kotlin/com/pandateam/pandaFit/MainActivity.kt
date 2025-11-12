package com.pandateam.pandaFit

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge mode before calling super.onCreate()
        // This is the recommended approach for Android 15+ compatibility
        enableEdgeToEdge()

        super.onCreate(savedInstanceState)
    }
}
