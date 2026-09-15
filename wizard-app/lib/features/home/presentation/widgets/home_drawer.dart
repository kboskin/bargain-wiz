import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:appwizard/core/di/injection_container.dart' as di;
import 'package:appwizard/core/services/feature_gate_service.dart';
import 'package:appwizard/core/services/remote_config_service.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_mascot.dart';
import 'package:appwizard/core/widgets/wiz/wiz_toast.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_event.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/auth/presentation/pages/sign_in_modal.dart';
import 'package:appwizard/features/home/presentation/utils/home_cta_tags.dart';
import 'package:appwizard/features/home/presentation/widgets/rate_us_dialog.dart';
import 'package:appwizard/features/home/presentation/widgets/refer_sheet.dart';
import 'package:appwizard/features/main_shell/domain/main_tab.dart';
import 'package:appwizard/features/main_shell/presentation/main_shell_controller.dart';
import 'package:appwizard/l10n/app_localizations.dart';

/// Legacy navigation drawer (README §10): left 290px, frosted 82% + blur 24, right border,
/// padding 70 18 44; brand row, 48h items, footer "v2.0 · {tier}".
class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key});

  static const double width = 290;
  static const String appVersion = 'v2.0';

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  late final FeatureGateService _gate = di.sl<FeatureGateService>();

  @override
  void initState() {
    super.initState();
    _gate.addListener(_onTier);
    if (_gate.lastTier == null) _gate.currentTier().then((_) => mounted ? setState(() {}) : null);
  }

  void _onTier() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gate.removeListener(_onTier);
    super.dispose();
  }

  void _close() {
    final shell = MainShellScope.maybeOf(context, listen: false);
    if (shell != null) {
      shell.closeDrawer();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goTab(MainTab tab) {
    _close();
    MainShellScope.maybeOf(context, listen: false)?.select(tab);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rc = di.sl<RemoteConfigService>();
    final termsUrl = rc.getTermsOfUseUrl();
    final privacyUrl = rc.getPrivacyPolicyUrl();
    final rootContext = context;

    return Drawer(
      width: HomeDrawer.width,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: const BoxDecoration(
              color: WizColors.frostedDrawer,
              border: Border(right: BorderSide(color: WizColors.frostedBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 70, 18, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, 22),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WizBrandRow(size: 28, textStyle: WizType.sectionTitle),
                  ),
                ),
                DrawerItem(
                  icon: Icons.person_outline,
                  label: l10n.profile,
                  onTap: () => _goTab(MainTab.profile),
                ),
                DrawerItem(
                  icon: Icons.view_agenda_outlined,
                  label: l10n.bargainsHistory,
                  onTap: () => _goTab(MainTab.history),
                ),
                DrawerItem(
                  icon: Icons.star_outline_rounded,
                  label: l10n.rateUs,
                  onTap: () {
                    _close();
                    RateUsDialog.show(rootContext);
                  },
                ),
                DrawerItem(
                  icon: Icons.card_giftcard_rounded,
                  label: l10n.refer,
                  onTap: () {
                    _close();
                    ReferSheet.show(rootContext);
                  },
                ),
                if (termsUrl.isNotEmpty)
                  DrawerItem(
                    icon: Icons.description_outlined,
                    label: l10n.terms,
                    onTap: () {
                      _close();
                      _launch(termsUrl);
                    },
                  ),
                if (privacyUrl.isNotEmpty)
                  DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.privacy,
                    onTap: () {
                      _close();
                      _launch(privacyUrl);
                    },
                  ),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final signedIn = state is AuthAuthenticated;
                    return DrawerItem(
                      icon: signedIn ? Icons.logout_rounded : Icons.login_rounded,
                      label: signedIn ? l10n.logOut : l10n.signIn,
                      color: WizColors.errorText,
                      onTap: () {
                        _close();
                        if (signedIn) {
                          rootContext.read<AuthBloc>().add(const SignOutRequested());
                          WizToast.show(rootContext, 'Logged out');
                        } else {
                          SignInModal.show(rootContext);
                        }
                      },
                    );
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${HomeDrawer.appVersion} · ${tierLabel(_gate.lastTier)}',
                    style: WizType.footnote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 48h drawer row, radius 14, Figtree 16/500 with a 22px icon slot.
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = WizColors.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(WizRadii.thumbLg),
            splashColor: WizColors.inkFaint,
            highlightColor: WizColors.inkFaint,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(width: 22, child: Icon(icon, size: 20, color: color)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: WizType.bodyFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
