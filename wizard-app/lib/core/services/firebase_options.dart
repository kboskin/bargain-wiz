// Firebase configuration for wizard-app-dev
// This file contains the dev environment configuration
// For prod, create separate FirebaseOptions or use flavor-specific configuration

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options based on the current platform and flavor
/// Currently configured for DEV environment
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // DEV Firebase configuration (wizard-app-dev)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADziGIZqIssPmnDm7rveLK7l79ku3AzQg',
    appId: '1:159613662745:android:e800964d29878d5fbc5c88',
    messagingSenderId: '159613662745',
    projectId: 'wizard-app-dev',
    storageBucket: 'wizard-app-dev.firebasestorage.app',
  );

  // DEV Firebase configuration (wizard-app-dev)
  // Bundle ID: com.bargain.wiz.dev (for dev flavor)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGD-dzOCoBUkNMHfwDqvtwfpCHGlPPNGg',
    appId: '1:159613662745:ios:159613bf7aa2b8e2bc5c88',
    messagingSenderId: '159613662745',
    projectId: 'wizard-app-dev',
    storageBucket: 'wizard-app-dev.firebasestorage.app',
    iosBundleId: 'com.bargain.wiz.dev', // Dev bundle ID
  );

  // TODO: Add PROD Firebase configuration when available
  // static const FirebaseOptions androidProd = FirebaseOptions(...);
  // static const FirebaseOptions iosProd = FirebaseOptions(...);
}

