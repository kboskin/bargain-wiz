import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/widgets/visual_asset_widget.dart';
import 'package:appwizard/data/models/multilocale_text.dart';
import 'package:appwizard/data/models/remote_config/main_page_config.dart';
import 'package:appwizard/l10n/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(final BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mainPageConfig = di.sl<RemoteConfigService>().getMainPageConfig();

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawerScrimColor: Colors.black.withValues(alpha: 0.2),
      appBar: AppBar(
        // Default leading opens drawer when Scaffold has a drawer
        title: Text(
          l10n.appTitle,
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(
                alpha: mainPageConfig?.stripeOpacity ?? 0.12,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _onStartNewNegotiation(context),
            tooltip: l10n.startNewNegotiation,
          ),
        ],
      ),
      drawer: _HomeDrawer(l10n: l10n),
      body: SafeArea(
        child: _EmptyStateContent(l10n: l10n, config: mainPageConfig),
      ),
    );
  }

  void _onStartNewNegotiation(BuildContext context) {
    // TODO: Navigate to new negotiation / upload flow
  }
}

Future<void> _pickImageFromGallery(BuildContext context) async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(source: ImageSource.gallery);
  if (!context.mounted) return;
  if (file != null) {
    // TODO: use the picked screenshot (e.g. navigate to analysis flow)
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(final BuildContext context) => Drawer(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Slightly stronger blur
        child: Container(
          decoration: BoxDecoration(
            // Use a gradient for a more realistic "frosted glass" shine
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.15),
              ],
            ),
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.5), // Brighter crisp edge
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Header instead of the bulky default DrawerHeader
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      // Optional: Add a little icon or logo next to the title
                      Icon(
                        Icons.auto_awesome,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.appTitle,
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle divider
                Divider(
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                const SizedBox(height: 16),

                // Menu Items
                _buildDrawerItem(
                  context: context,
                  icon: Icons.person_outline,
                  title: l10n.profile,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to profile
                  },
                ),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.history,
                  title: l10n.bargainsHistory,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to bargains history
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  // Helper widget for cleaner, pill-shaped list items
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(
          title,
          style: AppTextStyles.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        // Make the tap splash effect blend nicely with the glass
        splashColor: Colors.white.withValues(alpha: 0.3),
        hoverColor: Colors.white.withValues(alpha: 0.1),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyStateContent extends StatelessWidget {
  const _EmptyStateContent({required this.l10n, this.config});

  final AppLocalizations l10n;
  final MainPageConfig? config;

  String _headerText(BuildContext context) =>
      (config?.headerText as MultilocaleText?)?.get(context) ??
          l10n.homeEmptyTitle;

  String _uploadText(BuildContext context) =>
      (config?.uploadButtonText as MultilocaleText?)?.get(context) ??
          l10n.uploadScreenshot;

  String _enterTextText(BuildContext context) =>
      (config?.enterTextButtonText as MultilocaleText?)?.get(context) ??
          l10n.enterTextManually;

  String _pickupLinesText(BuildContext context) =>
      (config?.getPickupLinesButtonText as MultilocaleText?)?.get(context) ??
          l10n.getPickupLines;

  @override
  Widget build(BuildContext context) {
    final centerVisual = config?.centerVisual;

    return Column(
      children: [
        // 1. TEXT: Centered in the flexible space between the top and the image
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _headerText(context),
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),

        // 2. IMAGE: Sits in the middle because it's sandwiched between an Expanded and a Spacer
        if (centerVisual != null)
          VisualAssetWidget(
            visualPath: centerVisual.visual,
            width: centerVisual.width ?? 200,
            height: centerVisual.height ?? 200,
          )
        else
          const SizedBox(height: 200),

        // 3. SPACER: Balances the top Expanded space to keep the image centered
        const Spacer(),

        // 4. BUTTONS: Pinned safely to the bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _pickImageFromGallery(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _uploadText(context),
                    style: AppTextStyles.buttonText,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Enter text manually
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: AppColors.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _enterTextText(context),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Get pickup lines
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: AppColors.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _pickupLinesText(context),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

