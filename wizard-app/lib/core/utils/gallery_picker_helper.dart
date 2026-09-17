import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/core/widgets/wiz/wiz_sheet.dart';
import 'package:appwizard/features/shared/data/models/multilocale_text.dart';
import 'package:appwizard/features/home/data/models/main_page_config.dart';

/// Shared gallery picker: requests photo permission, shows configurable
/// dialogs/snackbars, and returns picked image file(s). Use for "Upload Product
/// or Chat" and for chat attachments.
class GalleryPickerHelper {
  GalleryPickerHelper._();

  /// Prevents opening the picker twice (e.g. duplicate tap or lifecycle after permission).
  static bool _isPickerOpen = false;
  static DateTime? _lastPickerClosedAt;
  static const Duration _pickerCooldown = Duration(milliseconds: 600);

  static String _photoPermissionText(
    BuildContext context,
    dynamic source,
    String fallback,
  ) {
    if (source == null) return fallback;
    if (source is MultilocaleText) return source.get(context);
    if (source is String && source.isNotEmpty) return source;
    return fallback;
  }

  static void _showPhotoPermissionDeniedDialog(
    BuildContext context,
    MainPageConfig? config,
  ) {
    final title = _photoPermissionText(
      context,
      config?.photoPermissionDeniedTitle,
      'Photo access',
    );
    final message = _photoPermissionText(
      context,
      config?.photoPermissionDeniedMessage,
      'Photo library access was denied. To pick a screenshot, allow access in Settings.',
    );
    final openSettingsLabel = _photoPermissionText(
      context,
      config?.openSettingsButtonText,
      'Open Settings',
    );
    final cancelLabel = _photoPermissionText(
      context,
      config?.cancelButtonText,
      MaterialLocalizations.of(context).cancelButtonLabel,
    );
    // Photo access dialog (design handoff §10): 64px amber camera disc, Outfit 22 title,
    // body from photo_permission_denied_message, Cancel (outlined) / Open Settings (ink) 50h.
    WizDialog.show<void>(
      context,
      builder: (ctx) => WizDialog(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: WizColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 26,
                  color: WizColors.amber,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: WizType.titleXs),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: WizType.bodySm),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: WizSecondaryButton(
                    height: 50,
                    label: cancelLabel,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: WizPrimaryButton(
                    height: 50,
                    label: openSettingsLabel,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      openAppSettings();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Picks image(s) from the gallery. Requests [Permission.photos], shows
  /// permission-denied dialog/snackbars on error. Returns the list of
  /// picked files (empty if cancelled or error). Guards against double-open.
  static Future<List<XFile>> pickImages(BuildContext context) async {
    if (_isPickerOpen) return [];
    final now = DateTime.now();
    if (_lastPickerClosedAt != null &&
        now.difference(_lastPickerClosedAt!) < _pickerCooldown) {
      return [];
    }
    final config = di.sl<RemoteConfigService>().getMainPageConfig();
    final logger = di.sl<AppLogger>();
    try {
      try {
        final status = await Permission.photos.request();
        if (!context.mounted) return [];
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            _showPhotoPermissionDeniedDialog(context, config);
            return [];
          }
          final snackbarText = _photoPermissionText(
            context,
            config?.photoPermissionSnackbar,
            'Photo access is needed to pick a screenshot.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(snackbarText)),
          );
          return [];
        }
      } on MissingPluginException catch (e, stackTrace) {
        logger.e(
          'Permission handler not registered (e.g. after hot restart), opening picker anyway',
          e,
          stackTrace,
        );
        if (!context.mounted) return [];
      }

      // Defer opening the picker to the next frame so the permission dialog
      // can fully dismiss and avoid the native picker opening twice.
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return [];

      _isPickerOpen = true;
      try {
        final picker = ImagePicker();
        // maxWidth/imageQuality make the OS re-encode to JPEG (iOS photos are HEIC
        // otherwise, which the on-device encoder cannot read) and cap the file size.
        final images = await picker.pickMultiImage(maxWidth: 2048, imageQuality: 90);
        if (!context.mounted) return [];
        return images;
      } finally {
        _isPickerOpen = false;
        _lastPickerClosedAt = DateTime.now();
      }
    } on PlatformException catch (e, stackTrace) {
      _isPickerOpen = false;
      logger.e('Gallery picker platform error: ${e.code}', e, stackTrace);
      if (!context.mounted) return [];
      final message = e.code == 'channel-error'
          ? _photoPermissionText(
              context,
              config?.galleryUnavailableMessage,
              'Gallery is temporarily unavailable. Try fully restarting the app.',
            )
          : (e.message ??
              _photoPermissionText(
                context,
                config?.galleryErrorMessage,
                'Could not open gallery.',
              ));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return [];
    } catch (e, stackTrace) {
      _isPickerOpen = false;
      logger.e('Gallery picker error', e, stackTrace);
      if (!context.mounted) return [];
      final message = _photoPermissionText(
        context,
        config?.galleryErrorTryAgainMessage,
        'Could not open gallery. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return [];
    }
  }

  /// Picks a single image (convenience). Returns the first picked file or null.
  static Future<XFile?> pickImage(BuildContext context) async {
    final list = await pickImages(context);
    if (list.isEmpty) return null;
    return list.first;
  }
}
