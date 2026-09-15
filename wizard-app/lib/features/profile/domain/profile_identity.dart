/// Display copy for the Profile account card, derived from the signed-in user (or guest).
/// Pure Dart so it can be unit-tested without Firebase.
class ProfileIdentity {
  const ProfileIdentity({
    required this.name,
    required this.initial,
    required this.subtitle,
    required this.signedIn,
  });

  static const String guestName = 'Guest wizard';
  static const String guestSubtitle = 'Sign in to sync deals across devices';

  final String name;
  final String initial;
  final String subtitle;
  final bool signedIn;

  static const ProfileIdentity guest = ProfileIdentity(
    name: guestName,
    initial: '?',
    subtitle: guestSubtitle,
    signedIn: false,
  );

  /// [displayName] ?? email local part ?? "Wizard"; subtitle "{email} · {provider}".
  static ProfileIdentity signedInUser({
    String? displayName,
    String? email,
    String? providerId,
  }) {
    final trimmedName = displayName?.trim() ?? '';
    final localPart = (email != null && email.contains('@')) ? email.split('@').first : (email ?? '');
    final name = trimmedName.isNotEmpty ? trimmedName : (localPart.isNotEmpty ? localPart : 'Wizard');
    final provider = providerLabel(providerId);
    final parts = <String>[
      if (email != null && email.isNotEmpty) email,
      if (provider.isNotEmpty) provider,
    ];
    return ProfileIdentity(
      name: name,
      initial: String.fromCharCode(name.runes.first).toUpperCase(),
      subtitle: parts.isEmpty ? 'Signed in' : parts.join(' · '),
      signedIn: true,
    );
  }

  static String providerLabel(String? providerId) {
    switch (providerId) {
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      case 'password':
        return 'Email';
      case 'facebook.com':
        return 'Facebook';
      case null:
      case '':
        return '';
      default:
        return providerId;
    }
  }
}
