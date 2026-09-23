import 'package:json_annotation/json_annotation.dart';

part 'profile_api_models.g.dart';

/// Request/response models of the `profile` Cloud Function (Firestore `profiles/{id}`).
/// See PROFILE_SYNC.md for the schema and merge rules.

/// The `preferences` section is a plain `{field: value}` map and the only record of what the
/// person answered: every screen that declares a `key` (`vibe`, `push`, …) writes one, plus
/// the device locale. The app copies the fields; the backend types the ones it reads and
/// keeps the rest as sent, so a question added in Remote Config is recorded without a deploy.

/// Whether the funnel is finished. The client reports the fact and the server stamps the
/// time, so a wrong device clock cannot date it. The answers themselves are `preferences`:
/// there is no second copy of them (PROFILE_SYNC.md).
@JsonSerializable(includeIfNull: false)
class ProfileOnboardingStatus {
  const ProfileOnboardingStatus({this.completed, this.completedAt});

  factory ProfileOnboardingStatus.fromJson(Map<String, dynamic> json) =>
      _$ProfileOnboardingStatusFromJson(json);

  /// Request only: `true` stamps `completed_at` on the server.
  @JsonKey(name: 'completed')
  final bool? completed;

  /// Response only.
  @JsonKey(name: 'completed_at')
  final String? completedAt;

  Map<String, dynamic> toJson() => _$ProfileOnboardingStatusToJson(this);
}

@JsonSerializable(includeIfNull: false)
class ProfileReferral {
  const ProfileReferral({this.code, this.enteredAt});

  factory ProfileReferral.fromJson(Map<String, dynamic> json) => _$ProfileReferralFromJson(json);

  @JsonKey(name: 'code')
  final String? code;
  @JsonKey(name: 'entered_at')
  final String? enteredAt;

  Map<String, dynamic> toJson() => _$ProfileReferralToJson(this);
}

@JsonSerializable(includeIfNull: false)
class ProfileApp {
  const ProfileApp({this.platform, this.version, this.locale, this.fcmToken, this.lastOpenedAt});

  factory ProfileApp.fromJson(Map<String, dynamic> json) => _$ProfileAppFromJson(json);

  @JsonKey(name: 'platform')
  final String? platform;
  @JsonKey(name: 'version')
  final String? version;
  @JsonKey(name: 'locale')
  final String? locale;

  /// This install's FCM registration token, the address a push to this person goes to.
  @JsonKey(name: 'fcm_token')
  final String? fcmToken;

  /// When this install was last launched: ISO-8601 UTC, sent by the launch report.
  @JsonKey(name: 'last_opened_at')
  final String? lastOpenedAt;

  Map<String, dynamic> toJson() => _$ProfileAppToJson(this);
}

/// Server-managed identity block (read-only for the client).
@JsonSerializable(includeIfNull: false)
class ProfileIdentity {
  const ProfileIdentity({this.uid, this.provider});

  factory ProfileIdentity.fromJson(Map<String, dynamic> json) => _$ProfileIdentityFromJson(json);

  @JsonKey(name: 'uid')
  final String? uid;
  @JsonKey(name: 'provider')
  final String? provider;

  Map<String, dynamic> toJson() => _$ProfileIdentityToJson(this);
}

/// Body of `PATCH /profile`: every section optional; nested maps merge, `null` deletes.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ProfilePatchRequest {
  const ProfilePatchRequest({this.preferences, this.onboardingStatus, this.referral, this.app});

  factory ProfilePatchRequest.fromJson(Map<String, dynamic> json) => _$ProfilePatchRequestFromJson(json);

  @JsonKey(name: 'preferences')
  final Map<String, dynamic>? preferences;
  @JsonKey(name: 'onboarding_status')
  final ProfileOnboardingStatus? onboardingStatus;
  @JsonKey(name: 'referral')
  final ProfileReferral? referral;
  @JsonKey(name: 'app')
  final ProfileApp? app;

  Map<String, dynamic> toJson() => _$ProfilePatchRequestToJson(this);
}

/// The stored document as returned by GET / PATCH.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ProfileDocument {
  const ProfileDocument({
    this.schemaVersion,
    this.identity,
    this.preferences,
    this.onboardingStatus,
    this.referral,
    this.app,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileDocument.fromJson(Map<String, dynamic> json) => _$ProfileDocumentFromJson(json);

  @JsonKey(name: 'schema_version')
  final int? schemaVersion;
  @JsonKey(name: 'identity')
  final ProfileIdentity? identity;
  @JsonKey(name: 'preferences')
  final Map<String, dynamic>? preferences;
  @JsonKey(name: 'onboarding_status')
  final ProfileOnboardingStatus? onboardingStatus;
  @JsonKey(name: 'referral')
  final ProfileReferral? referral;
  @JsonKey(name: 'app')
  final ProfileApp? app;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  Map<String, dynamic> toJson() => _$ProfileDocumentToJson(this);
}
