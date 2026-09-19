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
      textColor: json['text_color'] as String?,
      description: _multilocaleFromJson(json['description']),
      sideTextAlignment: OnboardingMetadata._sideTextAlignmentFromJson(
        json['side_text_alignment'] as String?,
      ),
      sideText: _multilocaleFromJson(json['side_text']),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      color: json['color'] as String?,
      short: _multilocaleFromJson(json['short']),
      animation: json['animation'] as String?,
      animationColor: json['animation_color'] as String?,
      buttons: json['buttons'] as List<dynamic>?,
      options: json['options'] as List<dynamic>?,
      paywallConfigKey: json['paywall_config_key'] as String?,
      paywallId: json['paywall_id'] as String?,
      placeholder: _multilocaleFromJson(json['placeholder']),
      imageSpacing: (json['image_spacing'] as num?)?.toDouble(),
      imageWidth: (json['image_width'] as num?)?.toDouble(),
      imageHeight: (json['image_height'] as num?)?.toDouble(),
      buttonVisual: json['button_visual'] as String?,
      buttonVisualWidth: (json['button_visual_width'] as num?)?.toDouble(),
      buttonVisualHeight: (json['button_visual_height'] as num?)?.toDouble(),
      buttonColor: json['button_color'] as String?,
      glowColor: json['glow_color'] as String?,
      glowIntensity: (json['glow_intensity'] as num?)?.toDouble(),
      buttonText: _multilocaleFromJson(json['button_text']),
      buttonStyle: json['button_style'] as String?,
      subtext: _multilocaleFromJson(json['subtext']),
      raw: json['raw'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OnboardingMetadataToJson(OnboardingMetadata instance) =>
    <String, dynamic>{
      'highlight_words': instance.highlightWords,
      'highlight_color': instance.highlightColor,
      'text_color': instance.textColor,
      'description': instance.description,
      'side_text_alignment': OnboardingMetadata._sideTextAlignmentToJson(
        instance.sideTextAlignment,
      ),
      'side_text': instance.sideText,
      'width': instance.width,
      'height': instance.height,
      'color': instance.color,
      'short': instance.short,
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
      'subtext': instance.subtext,
    };

AnswerStructure _$AnswerStructureFromJson(Map<String, dynamic> json) =>
    AnswerStructure(
      answerKeyName: json['answer_key_name'] as String,
      multi: json['multi'] as bool? ?? false,
    );

Map<String, dynamic> _$AnswerStructureToJson(AnswerStructure instance) =>
    <String, dynamic>{
      'answer_key_name': instance.answerKeyName,
      'multi': instance.multi,
    };

EngagementScreenModel _$EngagementScreenModelFromJson(
  Map<String, dynamic> json,
) => EngagementScreenModel(
  title: _multilocaleFromJson(json['title']),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
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
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

OnboardingOption _$OnboardingOptionFromJson(Map<String, dynamic> json) =>
    OnboardingOption(
      label: _multilocaleFromJson(json['label']),
      value: _multilocaleFromJson(json['value']),
      iconRaw: json['icon'],
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
      'icon': instance.iconRaw,
      'tint_color': instance.tintColor,
      'metadata': instance.metadata,
    };

SelectScreenModel _$SelectScreenModelFromJson(Map<String, dynamic> json) =>
    SelectScreenModel(
      title: _multilocaleFromJson(json['title']),
      description: _multilocaleFromJson(json['description']),
      options: (json['options'] as List<dynamic>)
          .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextButtonText: _multilocaleFromJson(json['next_button_text']),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
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
      'highlight_words': ?instance.highlightWords?.toJson(),
      'highlight_color': ?instance.highlightColor,
    };

MultiSelectScreenModel _$MultiSelectScreenModelFromJson(
  Map<String, dynamic> json,
) => MultiSelectScreenModel(
  title: _multilocaleFromJson(json['title']),
  options: (json['options'] as List<dynamic>)
      .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
);

Map<String, dynamic> _$MultiSelectScreenModelToJson(
  MultiSelectScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'options': instance.options.map((e) => e.toJson()).toList(),
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

SelectGroup _$SelectGroupFromJson(Map<String, dynamic> json) => SelectGroup(
  label: _multilocaleFromJson(json['label']),
  answerKeyName: json['answer_key_name'] as String,
  options: (json['options'] as List<dynamic>)
      .map((e) => OnboardingOption.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SelectGroupToJson(SelectGroup instance) =>
    <String, dynamic>{
      'label': ?instance.label,
      'answer_key_name': instance.answerKeyName,
      'options': instance.options.map((e) => e.toJson()).toList(),
    };

SelectGroupScreenModel _$SelectGroupScreenModelFromJson(
  Map<String, dynamic> json,
) => SelectGroupScreenModel(
  title: _multilocaleFromJson(json['title']),
  groups: (json['groups'] as List<dynamic>)
      .map((e) => SelectGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  description: _multilocaleFromJson(json['description']),
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
);

Map<String, dynamic> _$SelectGroupScreenModelToJson(
  SelectGroupScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'groups': instance.groups.map((e) => e.toJson()).toList(),
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

SliderOption _$SliderOptionFromJson(Map<String, dynamic> json) => SliderOption(
  value: (json['value'] as num).toDouble(),
  label: _multilocaleFromJson(json['label']),
  subtext: _multilocaleFromJson(json['subtext']),
  animation: json['animation'] as String?,
  animationWidth: (json['animation_width'] as num?)?.toDouble(),
  animationHeight: (json['animation_height'] as num?)?.toDouble(),
  savingsLow: (json['savings_low'] as num?)?.toInt(),
  savingsHigh: (json['savings_high'] as num?)?.toInt(),
  scale: (json['scale'] as num?)?.toDouble(),
  prompt: _stringOrNull(json['prompt']),
);

Map<String, dynamic> _$SliderOptionToJson(SliderOption instance) =>
    <String, dynamic>{
      'value': instance.value,
      'label': instance.label,
      'subtext': instance.subtext,
      'animation': instance.animation,
      'animation_width': instance.animationWidth,
      'animation_height': instance.animationHeight,
      'savings_low': instance.savingsLow,
      'savings_high': instance.savingsHigh,
      'scale': instance.scale,
      'prompt': instance.prompt,
    };

SliderScreenModel _$SliderScreenModelFromJson(Map<String, dynamic> json) =>
    SliderScreenModel(
      title: _multilocaleFromJson(json['title']),
      options: SliderScreenModel._sliderOptionsFromJson(json['options']),
      nextButtonText: _multilocaleFromJson(json['next_button_text']),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      description: _multilocaleFromJson(json['description']),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
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
      'highlight_words': ?instance.highlightWords?.toJson(),
      'highlight_color': ?instance.highlightColor,
    };

PermissionScreenModel _$PermissionScreenModelFromJson(
  Map<String, dynamic> json,
) => PermissionScreenModel(
  title: _multilocaleFromJson(json['title']),
  subtype: json['subtype'] as String? ?? 'notifications',
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
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
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

ImageListScreenModel _$ImageListScreenModelFromJson(
  Map<String, dynamic> json,
) => ImageListScreenModel(
  title: _multilocaleFromJson(json['title']),
  images: (json['images'] as List<dynamic>).map((e) => e as String).toList(),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
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
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

ReferralCodeScreenModel _$ReferralCodeScreenModelFromJson(
  Map<String, dynamic> json,
) => ReferralCodeScreenModel(
  title: _multilocaleFromJson(json['title']),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  referralCode: json['referral_code'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
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
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

PaywallScreenModel _$PaywallScreenModelFromJson(Map<String, dynamic> json) =>
    PaywallScreenModel(
      title: _multilocaleFromJson(json['title']),
      description: _multilocaleFromJson(json['description']),
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      nextButtonText: _multilocaleFromJson(json['next_button_text']),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
    );

Map<String, dynamic> _$PaywallScreenModelToJson(PaywallScreenModel instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'description': ?instance.description,
      'metadata': ?instance.metadata?.toJson(),
      'next_button_text': ?instance.nextButtonText,
      'answer_structure': ?instance.answerStructure?.toJson(),
      'show_top_bar': instance.showTopBar,
      'highlight_words': ?instance.highlightWords?.toJson(),
      'highlight_color': ?instance.highlightColor,
    };

DataUploadScreenModel _$DataUploadScreenModelFromJson(
  Map<String, dynamic> json,
) => DataUploadScreenModel(
  title: _multilocaleFromJson(json['title']),
  description: _multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  showTopBar: json['show_top_bar'] as bool? ?? false,
  showNextButton: json['show_next_button'] as bool? ?? false,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
);

Map<String, dynamic> _$DataUploadScreenModelToJson(
  DataUploadScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'visual': ?instance.visual,
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
  'show_next_button': instance.showNextButton,
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

CreateAccountScreenModel _$CreateAccountScreenModelFromJson(
  Map<String, dynamic> json,
) => CreateAccountScreenModel(
  title: _multilocaleFromJson(json['title']),
  description: _multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  googleButtonLabel: _multilocaleFromJson(json['google_button_label']),
  appleButtonLabel: _multilocaleFromJson(json['apple_button_label']),
  googlePlatforms: (json['google_platforms'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  applePlatforms: (json['apple_platforms'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
);

Map<String, dynamic> _$CreateAccountScreenModelToJson(
  CreateAccountScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'visual': ?instance.visual,
  'next_button_text': ?instance.nextButtonText,
  'show_top_bar': instance.showTopBar,
  'google_button_label': ?instance.googleButtonLabel,
  'apple_button_label': ?instance.appleButtonLabel,
  'google_platforms': ?instance.googlePlatforms,
  'apple_platforms': ?instance.applePlatforms,
  'metadata': ?instance.metadata?.toJson(),
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};

WarmupScreenModel _$WarmupScreenModelFromJson(Map<String, dynamic> json) =>
    WarmupScreenModel(
      title: _multilocaleFromJson(json['title']),
      nextButtonText: _multilocaleFromJson(json['next_button_text']),
      description: _multilocaleFromJson(json['description']),
      visual: json['visual'] as String?,
      metadata: json['metadata'] == null
          ? null
          : OnboardingMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      answerStructure: json['answer_structure'] == null
          ? null
          : AnswerStructure.fromJson(
              json['answer_structure'] as Map<String, dynamic>,
            ),
      showTopBar: json['show_top_bar'] as bool? ?? true,
      highlightWords: json['highlight_words'] == null
          ? null
          : HighlightWordsConfig.fromJson(
              json['highlight_words'] as Map<String, dynamic>,
            ),
      highlightColor: json['highlight_color'] as String?,
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
      'highlight_words': ?instance.highlightWords?.toJson(),
      'highlight_color': ?instance.highlightColor,
    };

SliderLottieScreenModel _$SliderLottieScreenModelFromJson(
  Map<String, dynamic> json,
) => SliderLottieScreenModel(
  title: _multilocaleFromJson(json['title']),
  nextButtonText: _multilocaleFromJson(json['next_button_text']),
  answerStructure: json['answer_structure'] == null
      ? null
      : AnswerStructure.fromJson(
          json['answer_structure'] as Map<String, dynamic>,
        ),
  description: _multilocaleFromJson(json['description']),
  visual: json['visual'] as String?,
  metadata: json['metadata'] == null
      ? null
      : OnboardingMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  showTopBar: json['show_top_bar'] as bool? ?? true,
  highlightWords: json['highlight_words'] == null
      ? null
      : HighlightWordsConfig.fromJson(
          json['highlight_words'] as Map<String, dynamic>,
        ),
  highlightColor: json['highlight_color'] as String?,
);

Map<String, dynamic> _$SliderLottieScreenModelToJson(
  SliderLottieScreenModel instance,
) => <String, dynamic>{
  'title': ?instance.title,
  'description': ?instance.description,
  'visual': ?instance.visual,
  'metadata': ?instance.metadata?.toJson(),
  'next_button_text': ?instance.nextButtonText,
  'answer_structure': ?instance.answerStructure?.toJson(),
  'show_top_bar': instance.showTopBar,
  'highlight_words': ?instance.highlightWords?.toJson(),
  'highlight_color': ?instance.highlightColor,
};
