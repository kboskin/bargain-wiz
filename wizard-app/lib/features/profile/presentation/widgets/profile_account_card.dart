import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/frosted_surface.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:appwizard/features/auth/presentation/bloc/auth_state.dart';
import 'package:appwizard/features/profile/domain/profile_identity.dart';

/// Account card: 56px avatar, name Outfit 20/700, sub Figtree 13, outlined 36h Sign in / Log out.
class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({super.key, required this.onSignIn, required this.onLogOut});

  final VoidCallback onSignIn;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final identity = state is AuthAuthenticated
              ? ProfileIdentity.signedInUser(
                  displayName: state.user.displayName,
                  email: state.user.email,
                  providerId: state.user.providerData.isNotEmpty
                      ? state.user.providerData.first.providerId
                      : null,
                )
              : ProfileIdentity.guest;
          final busy = state is AuthLoading;
          return FrostedSurface(
            radius: WizRadii.cardXl,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: identity.signedIn ? WizColors.purple : WizColors.borderStrong,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    identity.initial,
                    style: const TextStyle(
                      fontFamily: WizType.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WizType.status.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        identity.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WizType.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                WizSecondaryButton(
                  height: 36,
                  expand: false,
                  label: identity.signedIn ? 'Log out' : 'Sign in',
                  onPressed: busy ? null : (identity.signedIn ? onLogOut : onSignIn),
                ),
              ],
            ),
          );
        },
      );
}
