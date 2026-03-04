import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/main_page_config.dart';

/// Shared gallery picker: requests photo permission, shows configurable
/// dialogs/snackbars, and returns picked image file(s). Use for "Upload Product
/// or Chat" and for chat attachments.
class GalleryPickerHelper {
  GalleryPickerHelper._();

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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text(openSettingsLabel),
          ),
        ],
      ),
    );
  }

  /// Picks image(s) from the gallery. Requests [Permission.photos], shows
  /// permission-denied dialog or snackbars on error. Returns the list of
  /// picked files (empty if cancelled or error).
  static Future<List<XFile>> pickImages(BuildContext context) async {
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
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (!context.mounted) return [];
      return images;
    } on PlatformException catch (e, stackTrace) {
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
