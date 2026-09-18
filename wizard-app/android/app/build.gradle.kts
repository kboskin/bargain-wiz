plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.bargain.wiz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bargain.wiz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Bargain Wiz Dev")
            // Dev flavor is debuggable when built in debug mode (default behavior)
            // Use: flutter run --flavor dev (debug mode)
            // or: flutter build apk --flavor dev --debug
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Bargain Wiz")
        }
        // Dev app pointed at the Firebase emulators (flutter run --flavor local
        // --dart-define=FLAVOR=local). Same applicationId as dev so google-services.json
        // matches; src/local/AndroidManifest.xml allows http to the host machine.
        create("local") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-local"
            resValue("string", "app_name", "Bargain Wiz Local")
        }
    }

    buildTypes {
        debug {
            // Debug builds are always debuggable by default
            // Dev flavor in debug mode will be debuggable
            isDebuggable = true
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = false
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}
