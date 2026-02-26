package com.bargain.wiz

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ensure all plugins (e.g. image_picker, permission_handler) are registered.
        // Fixes MissingPluginException / channel-error when plugins fail to attach.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
