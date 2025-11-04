# Android Studio Configuration for Flavors

## Setting Up Run Configuration

To run the app with flavors in Android Studio:

### Option 1: Using Build Flavor Field (Recommended)

1. Open **Run** → **Edit Configurations...**
2. Select your configuration (or create a new one)
3. In the **Build flavor** field, enter: `dev` (for dev) or `prod` (for prod)
4. Click **Apply** and **OK**

### Option 2: Using Additional Run Args

1. Open **Run** → **Edit Configurations...**
2. Select your configuration
3. In the **Additional run args** field, enter:
   ```
   --flavor dev --dart-define=FLAVOR=dev
   ```
   For prod:
   ```
   --flavor prod --dart-define=FLAVOR=prod
   ```
4. Click **Apply** and **OK**

## Creating Multiple Configurations

You can create separate configurations for each flavor:

### Dev Configuration
- **Name**: `Dev Debug`
- **Build flavor**: `dev`
- **Additional run args**: `--dart-define=FLAVOR=dev`

### Prod Configuration
- **Name**: `Prod Debug`
- **Build flavor**: `prod`
- **Additional run args**: `--dart-define=FLAVOR=prod`

## Verifying Configuration

After setting up:
1. Select your configuration from the dropdown
2. Click the Run button
3. The app should build and install with the correct flavor

## Troubleshooting

If installation still fails:
1. **Sync Gradle**: File → Sync Project with Gradle Files
2. **Clean Build**: Build → Clean Project, then Build → Rebuild Project
3. **Invalidate Caches**: File → Invalidate Caches / Restart
4. **Check Build Variant**: Build → Select Build Variant → Choose `devDebug` or `prodDebug`

