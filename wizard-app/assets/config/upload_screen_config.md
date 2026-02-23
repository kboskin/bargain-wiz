# Upload progress screen – Remote Config

Remote Config key: **`upload_screen_config`**

This config drives the “upload user data” step (after “You’re All Set!”). All of the following are **remotely configurable** and **used in code** as below.

| RC key | Purpose | Where used in code |
|--------|---------|--------------------|
| **`lottie_asset`** | Lottie JSON path (e.g. `assets/lottie/onboarding_medium.json`). Animation progress is tied to the progress bar. | `DataUploadScreenWidget` → `_buildLottie()` → `widget.config.lottieAsset` (and `Lottie.asset()` / `Lottie.network()`) |
| **`texts`** | List of multilocale messages; one per progress segment (e.g. 0–33% = first text, 33–66% = second, 66–100% = third). | `DataUploadScreenWidget` → `build()` → `widget.config.texts`, `_segmentTextIndex()`, displayed in `Text(displayText)` |
| **`progress_ramp_seconds`** | Duration in seconds to ramp progress 0→90% (default 5). 100% when backend responds. | `DataUploadScreenWidget` → `_startProgressRamp()` → `widget.config.progressRampSeconds` |
| **`text_interval_seconds`** | (Legacy; texts are now segment-based, not time-based.) | Parsed but not used for display |

**Load path:** `RemoteConfigService.getUploadProgressScreenConfig(configKey)` (key from data_upload screen’s `metadata.upload_config_key`, default `upload_screen_config`) → passed as `config` into `DataUploadScreenWidget` in `onboarding_screen.dart` → all UI reads from `widget.config.*`.

## Example (defaults)

```json
{
  "lottie_asset": "assets/lottie/pot.json",
  "texts": [
    {"en": "Uploading your preferences...", "es": "Subiendo tus preferencias..."},
    {"en": "Syncing your data...", "es": "Sincronizando tus datos..."},
    {"en": "Almost there...", "es": "Casi listo..."}
  ],
  "text_interval_seconds": 2.5,
  "progress_ramp_seconds": 5
}
```

Set this JSON on the `upload_screen_config` key in Firebase Remote Config (or rely on app defaults from `remote_config_defaults.json`).
