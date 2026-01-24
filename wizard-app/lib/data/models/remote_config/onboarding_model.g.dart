// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnswerStructure _$AnswerStructureFromJson(Map<String, dynamic> json) =>
    AnswerStructure(answerKeyName: json['answer_key_name'] as String);

Map<String, dynamic> _$AnswerStructureToJson(AnswerStructure instance) =>
    <String, dynamic>{'answer_key_name': instance.answerKeyName};

EngagementScreenModel _$EngagementScreenModelFromJson(
  Map<String, dynamic> json,
) => EngagementScreenModel(
  title: json['title'],
  description: json['description'],
  visual: json['visual'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  nextButtonText: json['next_button_text'],
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? true,
);

Map<String, dynamic> _$EngagementScreenModelToJson(
  EngagementScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'visual': ?instance.visual,
  'metadata': ?instance.metadata,
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
};

OnboardingOption _$OnboardingOptionFromJson(Map<String, dynamic> json) =>
    OnboardingOption(
      label: json['label'],
      value: json['value'],
      icon: json['icon'] as String?,
      tintColor: json['tint_color'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OnboardingOptionToJson(OnboardingOption instance) =>
    <String, dynamic>{
      'label': instance.label,
      'value': instance.value,
      'icon': instance.icon,
      'tint_color': instance.tintColor,
      'metadata': instance.metadata,
    };

SelectScreenModel _$SelectScreenModelFromJson(Map<String, dynamic> json) =>
    SelectScreenModel(
      title: json['title'],
      description: json['description'],
      options: (json['options'] as List<dynamic>)
          .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      nextButtonText: json['nextButtonText'],
      answerStructure: json['answerStructure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answerStructure'] as Map<String, dynamic>,
            ),
      showTopBar: json['showTopBar'] as bool? ?? true,
    );

Map<String, dynamic> _$SelectScreenModelToJson(SelectScreenModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'nextButtonText': instance.nextButtonText,
      'answerStructure': instance.answerStructure,
      'showTopBar': instance.showTopBar,
      'options': instance.options,
      'metadata': instance.metadata,
    };

SliderOption _$SliderOptionFromJson(Map<String, dynamic> json) => SliderOption(
  value: (json['value'] as num).toDouble(),
  label: json['label'],
  animation: json['animation'] as String?,
  animationWidth: (json['animation_width'] as num?)?.toDouble(),
  animationHeight: (json['animation_height'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SliderOptionToJson(SliderOption instance) =>
    <String, dynamic>{
      'value': instance.value,
      'label': instance.label,
      'animation': instance.animation,
      'animation_width': instance.animationWidth,
      'animation_height': instance.animationHeight,
    };

SliderScreenModel _$SliderScreenModelFromJson(Map<String, dynamic> json) =>
    SliderScreenModel(
      title: json['title'],
      description: json['description'],
      options: (json['options'] as List<dynamic>)
          .map((e) => SliderOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      nextButtonText: json['nextButtonText'],
      answerStructure: json['answerStructure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answerStructure'] as Map<String, dynamic>,
            ),
      showTopBar: json['showTopBar'] as bool? ?? true,
    );

Map<String, dynamic> _$SliderScreenModelToJson(SliderScreenModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'nextButtonText': instance.nextButtonText,
      'answerStructure': instance.answerStructure,
      'showTopBar': instance.showTopBar,
      'options': instance.options,
      'metadata': instance.metadata,
    };

PermissionScreenModel _$PermissionScreenModelFromJson(
  Map<String, dynamic> json,
) => PermissionScreenModel(
  title: json['title'],
  description: json['description'],
  subtype: json['subtype'] as String,
  visual: json['visual'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  nextButtonText: json['nextButtonText'],
  answerStructure: json['answerStructure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answerStructure'] as Map<String, dynamic>,
        ),
  showTopBar: json['showTopBar'] as bool? ?? true,
);

Map<String, dynamic> _$PermissionScreenModelToJson(
  PermissionScreenModel instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'nextButtonText': instance.nextButtonText,
  'answerStructure': instance.answerStructure,
  'showTopBar': instance.showTopBar,
  'subtype': instance.subtype,
  'visual': instance.visual,
  'metadata': instance.metadata,
};

ImageListScreenModel _$ImageListScreenModelFromJson(
  Map<String, dynamic> json,
) => ImageListScreenModel(
  title: json['title'],
  description: json['description'],
  images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
  nextButtonText: json['nextButtonText'],
  answerStructure: json['answerStructure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answerStructure'] as Map<String, dynamic>,
        ),
  showTopBar: json['showTopBar'] as bool? ?? true,
);

Map<String, dynamic> _$ImageListScreenModelToJson(
  ImageListScreenModel instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'nextButtonText': instance.nextButtonText,
  'answerStructure': instance.answerStructure,
  'showTopBar': instance.showTopBar,
  'images': instance.images,
  'metadata': instance.metadata,
};

ReferralCodeScreenModel _$ReferralCodeScreenModelFromJson(
  Map<String, dynamic> json,
) => ReferralCodeScreenModel(
  title: json['title'],
  description: json['description'],
  referralCode: json['referralCode'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  nextButtonText: json['nextButtonText'],
  answerStructure: json['answerStructure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answerStructure'] as Map<String, dynamic>,
        ),
  showTopBar: json['showTopBar'] as bool? ?? true,
);

Map<String, dynamic> _$ReferralCodeScreenModelToJson(
  ReferralCodeScreenModel instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'nextButtonText': instance.nextButtonText,
  'answerStructure': instance.answerStructure,
  'showTopBar': instance.showTopBar,
  'referralCode': instance.referralCode,
  'metadata': instance.metadata,
};

PaywallScreenModel _$PaywallScreenModelFromJson(Map<String, dynamic> json) =>
    PaywallScreenModel(
      title: json['title'],
      description: json['description'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      nextButtonText: json['nextButtonText'],
      answerStructure: json['answerStructure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answerStructure'] as Map<String, dynamic>,
            ),
      showTopBar: json['showTopBar'] as bool? ?? true,
    );

Map<String, dynamic> _$PaywallScreenModelToJson(PaywallScreenModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'nextButtonText': instance.nextButtonText,
      'answerStructure': instance.answerStructure,
      'showTopBar': instance.showTopBar,
      'metadata': instance.metadata,
    };

WarmupScreenModel _$WarmupScreenModelFromJson(Map<String, dynamic> json) =>
    WarmupScreenModel(
      title: json['title'],
      description: json['description'],
      visual: json['visual'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      nextButtonText: json['next_button_text'],
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );

Map<String, dynamic> _$WarmupScreenModelToJson(WarmupScreenModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'visual': instance.visual,
      'metadata': instance.metadata,
      'next_button_text': instance.nextButtonText,
      'answer_structure': instance.answerStructure,
      'show_top_bar': instance.showTopBar,
    };
