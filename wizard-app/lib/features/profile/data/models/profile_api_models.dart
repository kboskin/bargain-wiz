import 'package:json_annotation/json_annotation.dart';

part 'profile_api_models.g.dart';

/// Request/response models of the `profile` Cloud Function (Firestore `profiles/{id}`).
/// See PROFILE_SYNC.md for the schema and merge rules.

/// Stable, typed preferences the app logic depends on (derived from onboarding answers).
@JsonSerializable(includeIfNull: false)
class ProfilePreferences {
  const ProfilePreferences({this.vibe, this.push, this.marketplace, this.dealsPerMonth, this.dealSize, this.locale, this.hurdles});

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) => _$ProfilePreferencesFromJson(json);

  final String? vibe;
  final int? push;
  final String? marketplace;
  @JsonKey(name: 'deals_per_month')
  final String? dealsPerMonth;
  @JsonKey(name: 'deal_size')
  final num? dealSize;
  final String? locale;

  /// Onboarding `main_hurdle` ids; the model compensates for them.
  final List<String>? hurdles;

  Map<String, dynamic> toJson() => _$ProfilePreferencesToJson(this);
}

/// One step of the onboarding trace: what was asked and which options were offered.
@JsonSerializable(includeIfNull: false)
class ProfileFlowStep {
  const ProfileFlowStep({this.index, this.key, this.type, this.title, this.options});

  factory ProfileFlowStep.fromJson(Map<String, dynamic> json) => _$ProfileFlowStepFromJson(json);

  final int? index;
  final String? key;
  final String? type;
  final String? title;
  final List<String>? options;

  Map<String, dynamic> toJson() => _$ProfileFlowStepToJson(this);
}

/// Raw funnel answers keyed by the remote-config `answer_key_name`, plus the [flow] of
/// screens that produced them (experiment assignment is tracked by Firebase A/B Testing).
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ProfileOnboarding {
  const ProfileOnboarding({this.answers, this.completed, this.completedAt, this.flow});

  factory ProfileOnboarding.fromJson(Map<String, dynamic> json) => _$ProfileOnboardingFromJson(json);

  final Map<String, dynamic>? answers;

  /// Request only: `true` stamps `completed_at` on the server.
  final bool? completed;

  /// Response only.
  @JsonKey(name: 'completed_at')
  final String? completedAt;

  final List<ProfileFlowStep>? flow;

  Map<String, dynamic> toJson() => _$ProfileOnboardingToJson(this);
}

@JsonSerializable(includeIfNull: false)
class ProfileReferral {
  const ProfileReferral({this.code, this.enteredAt});

  factory ProfileReferral.fromJson(Map<String, dynamic> json) => _$ProfileReferralFromJson(json);

  final String? code;
  @JsonKey(name: 'entered_at')
  final String? enteredAt;

  Map<String, dynamic> toJson() => _$ProfileReferralToJson(this);
}

@JsonSerializable(includeIfNull: false)
class ProfileApp {
  const ProfileApp({this.platform, this.version, this.flavor, this.locale});

  factory ProfileApp.fromJson(Map<String, dynamic> json) => _$ProfileAppFromJson(json);

  final String? platform;
  final String? version;
  final String? flavor;
  final String? locale;

  Map<String, dynamic> toJson() => _$ProfileAppToJson(this);
}

/// Server-managed identity block (read-only for the client).
@JsonSerializable(includeIfNull: false)
class ProfileIdentity {
  const ProfileIdentity({this.uid, this.provider, this.installationIds, this.mergedFrom, this.mergedInto});

  factory ProfileIdentity.fromJson(Map<String, dynamic> json) => _$ProfileIdentityFromJson(json);

  final String? uid;
  final String? provider;
  @JsonKey(name: 'installation_ids')
  final List<String>? installationIds;
  @JsonKey(name: 'merged_from')
  final List<String>? mergedFrom;
  @JsonKey(name: 'merged_into')
  final String? mergedInto;

  Map<String, dynamic> toJson() => _$ProfileIdentityToJson(this);
}

/// Body of `PATCH /profile`: every section optional; nested maps merge, `null` deletes.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class ProfilePatchRequest {
  const ProfilePatchRequest({required this.installationId, this.preferences, this.onboarding, this.referral, this.app});

  factory ProfilePatchRequest.fromJson(Map<String, dynamic> json) => _$ProfilePatchRequestFromJson(json);

  @JsonKey(name: 'installation_id')
  final String installationId;
  final ProfilePreferences? preferences;
  final ProfileOnboarding? onboarding;
  final ProfileReferral? referral;
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
    this.onboarding,
    this.referral,
    this.app,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileDocument.fromJson(Map<String, dynamic> json) => _$ProfileDocumentFromJson(json);

  @JsonKey(name: 'schema_version')
  final int? schemaVersion;
  final ProfileIdentity? identity;
  final ProfilePreferences? preferences;
  final ProfileOnboarding? onboarding;
  final ProfileReferral? referral;
  final ProfileApp? app;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  Map<String, dynamic> toJson() => _$ProfileDocumentToJson(this);
}
