# Keep Flutter plugins (Pigeon/platform channels) from being obfuscated.
# Prevents "channel-error: Unable to establish connection" in release builds
# when minifyEnabled true is used.
# See: https://github.com/flutter/flutter/issues/154580
-if class * implements io.flutter.embedding.engine.plugins.FlutterPlugin
-keep,allowshrinking,allowobfuscation class <1>
