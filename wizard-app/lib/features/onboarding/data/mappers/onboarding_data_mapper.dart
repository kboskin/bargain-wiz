import 'package:appwizard/core/utils/app_logger.dart';
import 'package:appwizard/features/onboarding/data/models/onboarding_data.dart';
import 'package:appwizard/features/onboarding/domain/entities/onboarding_data_entity.dart';
import 'package:appwizard/features/onboarding/data/models/remote_config/onboarding_screen_config.dart';
import 'package:appwizard/features/onboarding/data/mappers/onboarding_screen_type_mapper.dart';

/// Maps [OnboardingData] to/from [OnboardingDataEntity].
/// Uses [OnboardingScreenTypeMapper] for screen type enum serialization.
class OnboardingDataMapper {
  OnboardingDataMapper(this._screenTypeMapper, this._logger);

  final OnboardingScreenTypeMapper _screenTypeMapper;
  final AppLogger _logger;

  OnboardingData toModel(OnboardingDataEntity entity) {
    final answersMap = <String, dynamic>{};
    for (final answer in entity.answers) {
      final key = answer.answerKey ?? 'screen_${answer.screenIndex}';
      answersMap[key] = answer.answer;
    }
    return OnboardingData(
      isCompleted: entity.isCompleted,
      answers: answersMap,
    );
  }

  OnboardingDataEntity toEntity(OnboardingData data) {
    try {
      final answers = <OnboardingAnswer>[];
      for (final entry in data.answers.entries) {
        try {
          final key = entry.key;
          final answerValue = entry.value;
          if (key.startsWith('screen_') && answerValue is Map<String, dynamic>) {
            final index = int.tryParse(key.replaceFirst('screen_', '')) ?? 0;
            answers.add(OnboardingAnswer(
              screenIndex: index,
              screenTitle: answerValue['screenTitle'] as String? ?? '',
              screenType: _screenTypeMapper.toEntity(answerValue['screenType'] as String?),
              answerKey: answerValue['answerKey'] as String?,
              answer: answerValue['answer'],
            ));
          } else {
            final index = key.startsWith('screen_')
                ? int.tryParse(key.replaceFirst('screen_', '')) ?? 0
                : 0;
            answers.add(OnboardingAnswer(
              screenIndex: index,
              screenTitle: '',
              screenType: OnboardingScreenType.engagement,
              answerKey: key.startsWith('screen_') ? null : key,
              answer: answerValue,
            ));
          }
        } on Object catch (e) {
          _logger.w('OnboardingDataMapper: skipping invalid answer entry: $e');
        }
      }
      return OnboardingDataEntity(
        answers: answers,
        isCompleted: data.isCompleted,
      );
    } on Object catch (e, stackTrace) {
      _logger.e('OnboardingDataMapper.toEntity failed', e, stackTrace);
      return OnboardingDataEntity(
        answers: const [],
        isCompleted: data.isCompleted,
      );
    }
  }
}
