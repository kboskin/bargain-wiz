// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileOnboardingStatus _$ProfileOnboardingStatusFromJson(
  Map<String, dynamic> json,
) => ProfileOnboardingStatus(
  completed: json['completed'] as bool?,
  completedAt: json['completed_at'] as String?,
);

Map<String, dynamic> _$ProfileOnboardingStatusToJson(
  ProfileOnboardingStatus instance,
) => <String, dynamic>{
  'completed': ?instance.completed,
  'completed_at': ?instance.completedAt,
};

ProfileReferral _$ProfileReferralFromJson(Map<String, dynamic> json) =>
    ProfileReferral(
      code: json['code'] as String?,
      enteredAt: json['entered_at'] as String?,
    );

Map<String, dynamic> _$ProfileReferralToJson(ProfileReferral instance) =>
    <String, dynamic>{
      'code': ?instance.code,
      'entered_at': ?instance.enteredAt,
    };

ProfileApp _$ProfileAppFromJson(Map<String, dynamic> json) => ProfileApp(
  platform: json['platform'] as String?,
  version: json['version'] as String?,
  locale: json['locale'] as String?,
  fcmToken: json['fcm_token'] as String?,
);

Map<String, dynamic> _$ProfileAppToJson(ProfileApp instance) =>
    <String, dynamic>{
      'platform': ?instance.platform,
      'version': ?instance.version,
      'locale': ?instance.locale,
      'fcm_token': ?instance.fcmToken,
    };

ProfileIdentity _$ProfileIdentityFromJson(Map<String, dynamic> json) =>
    ProfileIdentity(
      uid: json['uid'] as String?,
      provider: json['provider'] as String?,
    );

Map<String, dynamic> _$ProfileIdentityToJson(ProfileIdentity instance) =>
    <String, dynamic>{'uid': ?instance.uid, 'provider': ?instance.provider};

ProfilePatchRequest _$ProfilePatchRequestFromJson(Map<String, dynamic> json) =>
    ProfilePatchRequest(
      preferences: json['preferences'] as Map<String, dynamic>?,
      onboardingStatus: json['onboarding_status'] == null
          ? null
          : ProfileOnboardingStatus.fromJson(
              json['onboarding_status'] as Map<String, dynamic>,
            ),
      referral: json['referral'] == null
          ? null
          : ProfileReferral.fromJson(json['referral'] as Map<String, dynamic>),
      app: json['app'] == null
          ? null
          : ProfileApp.fromJson(json['app'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProfilePatchRequestToJson(
  ProfilePatchRequest instance,
) => <String, dynamic>{
  'preferences': ?instance.preferences,
  'onboarding_status': ?instance.onboardingStatus?.toJson(),
  'referral': ?instance.referral?.toJson(),
  'app': ?instance.app?.toJson(),
};

ProfileDocument _$ProfileDocumentFromJson(Map<String, dynamic> json) =>
    ProfileDocument(
      schemaVersion: (json['schema_version'] as num?)?.toInt(),
      identity: json['identity'] == null
          ? null
          : ProfileIdentity.fromJson(json['identity'] as Map<String, dynamic>),
      preferences: json['preferences'] as Map<String, dynamic>?,
      onboardingStatus: json['onboarding_status'] == null
          ? null
          : ProfileOnboardingStatus.fromJson(
              json['onboarding_status'] as Map<String, dynamic>,
            ),
      referral: json['referral'] == null
          ? null
          : ProfileReferral.fromJson(json['referral'] as Map<String, dynamic>),
      app: json['app'] == null
          ? null
          : ProfileApp.fromJson(json['app'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$ProfileDocumentToJson(ProfileDocument instance) =>
    <String, dynamic>{
      'schema_version': ?instance.schemaVersion,
      'identity': ?instance.identity?.toJson(),
      'preferences': ?instance.preferences,
      'onboarding_status': ?instance.onboardingStatus?.toJson(),
      'referral': ?instance.referral?.toJson(),
      'app': ?instance.app?.toJson(),
      'created_at': ?instance.createdAt,
      'updated_at': ?instance.updatedAt,
    };
