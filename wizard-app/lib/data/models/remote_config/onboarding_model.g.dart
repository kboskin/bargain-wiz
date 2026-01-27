// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingMetadata _$OnboardingMetadataFromJson(Map<String, dynamic> json) =>
    OnboardingMetadata(
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
      description: OnboardingMetadata._multilocaleFromJson(json['description']),
      sideTextAlignment: OnboardingMetadata._sideTextAlignmentFromJson(
        json['side_text_alignment'] as String?,
      ),
      sideText: OnboardingMetadata._multilocaleFromJson(json['side_text']),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      color: json['color'] as String?,
      animation: json['animation'] as String?,
      animationColor: json['animation_color'] as String?,
      buttons: json['buttons'] as List<dynamic>?,
      options: json['options'] as List<dynamic>?,
      paywallConfigKey: json['paywall_config_key'] as String?,
      paywallId: json['paywall_id'] as String?,
      placeholder: OnboardingMetadata._multilocaleFromJson(json['placeholder']),
      imageSpacing: (json['image_spacing'] as num?)?.toDouble(),
      imageWidth: (json['image_width'] as num?)?.toDouble(),
      imageHeight: (json['image_height'] as num?)?.toDouble(),
      buttonVisual: json['button_visual'] as String?,
      buttonVisualWidth: (json['button_visual_width'] as num?)?.toDouble(),
      buttonVisualHeight: (json['button_visual_height'] as num?)?.toDouble(),
      buttonColor: json['button_color'] as String?,
      glowColor: json['glow_color'] as String?,
      glowIntensity: (json['glow_intensity'] as num?)?.toDouble(),
      buttonText: OnboardingMetadata._multilocaleFromJson(json['button_text']),
      buttonStyle: json['button_style'] as String?,
      raw: json['raw'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OnboardingMetadataToJson(OnboardingMetadata instance) =>
    <String, dynamic>{
      'highlight_words': instance.highlightWords,
      'highlight_color': instance.highlightColor,
      'description': instance.description,
      'side_text_alignment': OnboardingMetadata._sideTextAlignmentToJson(
        instance.sideTextAlignment,
      ),
      'side_text': instance.sideText,
      'width': instance.width,
      'height': instance.height,
      'color': instance.color,
      'animation': instance.animation,
      'animation_color': instance.animationColor,
      'buttons': instance.buttons,
      'options': instance.options,
      'paywall_config_key': instance.paywallConfigKey,
      'paywall_id': instance.paywallId,
      'placeholder': instance.placeholder,
      'image_spacing': instance.imageSpacing,
      'image_width': instance.imageWidth,
      'image_height': instance.imageHeight,
      'button_visual': instance.buttonVisual,
      'button_visual_width': instance.buttonVisualWidth,
      'button_visual_height': instance.buttonVisualHeight,
      'button_color': instance.buttonColor,
      'glow_color': instance.glowColor,
      'glow_intensity': instance.glowIntensity,
      'button_text': instance.buttonText,
      'button_style': instance.buttonStyle,
    };

AnswerStructure _$AnswerStructureFromJson(Map<String, dynamic> json) =>
    AnswerStructure(answerKeyName: json['answer_key_name'] as String);

Map<String, dynamic> _$AnswerStructureToJson(AnswerStructure instance) =>
    <String, dynamic>{'answer_key_name': instance.answerKeyName};

EngagementScreenModel _$EngagementScreenModelFromJson(
  Map<String, dynamic> json,
) => EngagementScreenModel(
  title: EngagementScreenModel._multilocaleFromJson(json['title']),
  description: EngagementScreenModel._multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: EngagementScreenModel._multilocaleFromJson(
    json['next_button_text'],
  ),
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
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
};

OnboardingOption _$OnboardingOptionFromJson(Map<String, dynamic> json) =>
    OnboardingOption(
      label: OnboardingOption._multilocaleFromJson(json['label']),
      value: OnboardingOption._multilocaleFromJson(json['value']),
      icon: json['icon'] as String?,
      tintColor: json['tint_color'] as String?,
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
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
      title: SelectScreenModel._multilocaleFromJson(json['title']),
      description: SelectScreenModel._multilocaleFromJson(json['description']),
      options: (json['options'] as List<dynamic>)
          .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      nextButtonText: SelectScreenModel._multilocaleFromJson(
        json['next_button_text'],
      ),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );

Map<String, dynamic> _$SelectScreenModelToJson(SelectScreenModel instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'description': ?instance.description,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'metadata': ?instance.metadata?.toJson(),
      'next_button_text': ?instance.nextButtonText,
      'answer_structure': ?instance.answerStructure?.toJson(),
      'show_top_bar': instance.showTopBar,
    };

SliderOption _$SliderOptionFromJson(Map<String, dynamic> json) => SliderOption(
  value: (json['value'] as num).toDouble(),
  label: SliderOption._multilocaleFromJson(json['label']),
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
      title: SliderScreenModel._multilocaleFromJson(json['title']),
      description: SliderScreenModel._multilocaleFromJson(json['description']),
      options: SliderScreenModel._sliderOptionsFromJson(json['options']),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      nextButtonText: SliderScreenModel._multilocaleFromJson(
        json['next_button_text'],
      ),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );

Map<String, dynamic> _$SliderScreenModelToJson(SliderScreenModel instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'description': ?instance.description,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'metadata': ?instance.metadata?.toJson(),
      'next_button_text': ?instance.nextButtonText,
      'answer_structure': ?instance.answerStructure?.toJson(),
      'show_top_bar': instance.showTopBar,
    };

PermissionScreenModel _$PermissionScreenModelFromJson(
  Map<String, dynamic> json,
) => PermissionScreenModel(
  title: PermissionScreenModel._multilocaleFromJson(json['title']),
  description: PermissionScreenModel._multilocaleFromJson(json['description']),
  subtype: json['subtype'] as String,
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: PermissionScreenModel._multilocaleFromJson(
    json['next_button_text'],
  ),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? true,
);

Map<String, dynamic> _$PermissionScreenModelToJson(
  PermissionScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'subtype': instance.subtype,
  'visual': ?instance.visual,
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
};

ImageListScreenModel _$ImageListScreenModelFromJson(
  Map<String, dynamic> json,
) => ImageListScreenModel(
  title: ImageListScreenModel._multilocaleFromJson(json['title']),
  description: ImageListScreenModel._multilocaleFromJson(json['description']),
  images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: ImageListScreenModel._multilocaleFromJson(
    json['next_button_text'],
  ),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? true,
);

Map<String, dynamic> _$ImageListScreenModelToJson(
  ImageListScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'images': instance.images,
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
};

ReferralCodeScreenModel _$ReferralCodeScreenModelFromJson(
  Map<String, dynamic> json,
) => ReferralCodeScreenModel(
  title: ReferralCodeScreenModel._multilocaleFromJson(json['title']),
  description: ReferralCodeScreenModel._multilocaleFromJson(
    json['description'],
  ),
  referralCode: json['referral_code'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: ReferralCodeScreenModel._multilocaleFromJson(
    json['next_button_text'],
  ),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? true,
);

Map<String, dynamic> _$ReferralCodeScreenModelToJson(
  ReferralCodeScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'referral_code': ?instance.referralCode,
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
};

PaywallScreenModel _$PaywallScreenModelFromJson(Map<String, dynamic> json) =>
    PaywallScreenModel(
      title: PaywallScreenModel._multilocaleFromJson(json['title']),
      description: PaywallScreenModel._multilocaleFromJson(json['description']),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      nextButtonText: PaywallScreenModel._multilocaleFromJson(
        json['next_button_text'],
      ),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );

Map<String, dynamic> _$PaywallScreenModelToJson(PaywallScreenModel instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'description': ?instance.description,
      'metadata': ?instance.metadata?.toJson(),
      'next_button_text': ?instance.nextButtonText,
      'answer_structure': ?instance.answerStructure?.toJson(),
      'show_top_bar': instance.showTopBar,
    };

WarmupScreenModel _$WarmupScreenModelFromJson(Map<String, dynamic> json) =>
    WarmupScreenModel(
      title: WarmupScreenModel._multilocaleFromJson(json['title']),
      description: WarmupScreenModel._multilocaleFromJson(json['description']),
      visual: json['visual'] as String?,
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      nextButtonText: WarmupScreenModel._multilocaleFromJson(
        json['next_button_text'],
      ),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
    );

Map<String, dynamic> _$WarmupScreenModelToJson(WarmupScreenModel instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'description': ?instance.description,
      'visual': ?instance.visual,
      'metadata': ?instance.metadata?.toJson(),
      'next_button_text': ?instance.nextButtonText,
      'answer_structure': ?instance.answerStructure?.toJson(),
      'show_top_bar': instance.showTopBar,
    };
