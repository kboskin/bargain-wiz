// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfilePreferences _$ProfilePreferencesFromJson(Map<String, dynamic> json) =>
    ProfilePreferences(
      vibe: json['vibe'] as String?,
      push: (json['push'] as num?)?.toInt(),
      marketplace: json['marketplace'] as String?,
      dealsPerMonth: json['deals_per_month'] as String?,
      dealSize: json['deal_size'] as num?,
      locale: json['locale'] as String?,
      hurdles: (json['hurdles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ProfilePreferencesToJson(ProfilePreferences instance) =>
    <String, dynamic>{
      'vibe': ?instance.vibe,
      'push': ?instance.push,
      'marketplace': ?instance.marketplace,
      'deals_per_month': ?instance.dealsPerMonth,
      'deal_size': ?instance.dealSize,
      'locale': ?instance.locale,
      'hurdles': ?instance.hurdles,
    };

ProfileFlowStep _$ProfileFlowStepFromJson(Map<String, dynamic> json) =>
    ProfileFlowStep(
      index: (json['index'] as num?)?.toInt(),
      key: json['key'] as String?,
      type: json['type'] as String?,
      title: json['title'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ProfileFlowStepToJson(ProfileFlowStep instance) =>
    <String, dynamic>{
      'index': ?instance.index,
      'key': ?instance.key,
      'type': ?instance.type,
      'title': ?instance.title,
      'options': ?instance.options,
    };

ProfileOnboarding _$ProfileOnboardingFromJson(Map<String, dynamic> json) =>
    ProfileOnboarding(
      answers: json['answers'] as Map<String, dynamic>?,
      completed: json['completed'] as bool?,
      completedAt: json['completed_at'] as String?,
      flow: (json['flow'] as List<dynamic>?)
          ?.map((e) => ProfileFlowStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ProfileOnboardingToJson(ProfileOnboarding instance) =>
    <String, dynamic>{
      'answers': ?instance.answers,
      'completed': ?instance.completed,
      'completed_at': ?instance.completedAt,
      'flow': ?instance.flow?.map((e) => e.toJson()).toList(),
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
  flavor: json['flavor'] as String?,
  locale: json['locale'] as String?,
);

Map<String, dynamic> _$ProfileAppToJson(ProfileApp instance) =>
    <String, dynamic>{
      'platform': ?instance.platform,
      'version': ?instance.version,
      'flavor': ?instance.flavor,
      'locale': ?instance.locale,
    };

ProfileIdentity _$ProfileIdentityFromJson(Map<String, dynamic> json) =>
    ProfileIdentity(
      uid: json['uid'] as String?,
      provider: json['provider'] as String?,
      installationIds: (json['installation_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mergedFrom: (json['merged_from'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mergedInto: json['merged_into'] as String?,
    );

Map<String, dynamic> _$ProfileIdentityToJson(ProfileIdentity instance) =>
    <String, dynamic>{
      'uid': ?instance.uid,
      'provider': ?instance.provider,
      'installation_ids': ?instance.installationIds,
      'merged_from': ?instance.mergedFrom,
      'merged_into': ?instance.mergedInto,
    };

ProfilePatchRequest _$ProfilePatchRequestFromJson(Map<String, dynamic> json) =>
    ProfilePatchRequest(
      installationId: json['installation_id'] as String,
      preferences: json['preferences'] == null
          ? null
          : ProfilePreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            ),
      onboarding: json['onboarding'] == null
          ? null
          : ProfileOnboarding.fromJson(
              json['onboarding'] as Map<String, dynamic>,
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
  'installation_id': instance.installationId,
  'preferences': ?instance.preferences?.toJson(),
  'onboarding': ?instance.onboarding?.toJson(),
  'referral': ?instance.referral?.toJson(),
  'app': ?instance.app?.toJson(),
};

ProfileDocument _$ProfileDocumentFromJson(Map<String, dynamic> json) =>
    ProfileDocument(
      schemaVersion: (json['schema_version'] as num?)?.toInt(),
      identity: json['identity'] == null
          ? null
          : ProfileIdentity.fromJson(json['identity'] as Map<String, dynamic>),
      preferences: json['preferences'] == null
          ? null
          : ProfilePreferences.fromJson(
              json['preferences'] as Map<String, dynamic>,
            ),
      onboarding: json['onboarding'] == null
          ? null
          : ProfileOnboarding.fromJson(
              json['onboarding'] as Map<String, dynamic>,
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
      'preferences': ?instance.preferences?.toJson(),
      'onboarding': ?instance.onboarding?.toJson(),
      'referral': ?instance.referral?.toJson(),
      'app': ?instance.app?.toJson(),
      'created_at': ?instance.createdAt,
      'updated_at': ?instance.updatedAt,
    };
