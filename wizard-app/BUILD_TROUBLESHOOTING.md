# Build Troubleshooting Guide

## Common Build Issues

### Error: "Gradle build failed to produce an .apk file"

This error typically occurs when:

1. **Build completed but file not found immediately**
   - Solution: Wait a few seconds and check manually
   - APK location: `build/app/outputs/flutter-apk/app-{flavor}-{buildType}.apk`

2. **Build actually failed**
   - Check the full error output: `flutter build apk --flavor dev --debug --verbose`
   - Look for Gradle errors in the output

3. **Path issues**
   - APKs are generated in multiple locations:
     - `build/app/outputs/flutter-apk/app-{flavor}-{buildType}.apk`
     - `build/app/outputs/apk/{flavor}/{buildType}/app-{flavor}-{buildType}.apk`

### Solutions

#### 1. Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter build apk --flavor dev --debug
```

#### 2. Check Build Output
```bash
# Find all APK files
find build -name "*.apk" -type f

# List build directory
ls -la build/app/outputs/flutter-apk/
```

#### 3. Build with Verbose Output
```bash
flutter build apk --flavor dev --debug --verbose
```

#### 4. Check Gradle Build Directly
```bash
cd android
./gradlew assembleDevDebug
```

#### 5. Verify Firebase Configuration
- Ensure `android/app/google-services.json` exists
- Ensure `ios/Runner/GoogleService-Info.plist` exists (for iOS)
- Verify Google Services plugin is properly configured

#### 6. Check Android Studio/VS Code
- Sometimes IDE caches can cause issues
- Try: File → Invalidate Caches / Restart (Android Studio)
- Or restart VS Code

### APK File Locations

After a successful build, APKs are located at:

- **Flutter default location**: `build/app/outputs/flutter-apk/app-{flavor}-{buildType}.apk`
- **Gradle flavor-specific**: `build/app/outputs/apk/{flavor}/{buildType}/app-{flavor}-{buildType}.apk`

Examples:
- Dev Debug: `build/app/outputs/flutter-apk/app-dev-debug.apk`
- Prod Debug: `build/app/outputs/flutter-apk/app-prod-debug.apk`
- Dev Release: `build/app/outputs/flutter-apk/app-dev-release.apk`
- Prod Release: `build/app/outputs/flutter-apk/app-prod-release.apk`

### Common Gradle Errors

#### Missing google-services.json
```
Execution failed for task ':app:processDevDebugGoogleServices'
```
**Solution**: Ensure `android/app/google-services.json` exists

#### Version conflicts
```
Conflict with dependency 'com.google...'
```
**Solution**: Run `flutter clean` and rebuild

#### Min SDK version issues
```
minSdkVersion 16 cannot be smaller than version 21
```
**Solution**: Check `android/app/build.gradle.kts` minSdk setting

### Verification Commands

```bash
# Check if build directory exists
ls -la build/

# Check for APK files
find build -name "*.apk"

# Check Gradle version
cd android && ./gradlew --version

# Check Flutter environment
flutter doctor -v
```

