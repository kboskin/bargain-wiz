import 'package:appwizard/core/utils/app_logger.dart';

/// Result of a single screenshot upload (mock/API).
class UploadScreenshotResultDto {
  const UploadScreenshotResultDto({this.id});
  final String? id;
}

/// Deal reply DTO from backend (multiple options).
class DealReplyDto {
  const DealReplyDto({required this.options});
  final List<String> options;
}

/// Remote data source for Express Dealmaker (upload screenshots, get reply).
/// Implement with mock or real HTTP client.
abstract class ExpressDealmakerRemoteDataSource {
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath);
  /// "Lines that land" API: returns deal reply options in the requested [locale].
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    final String? keyword,
    required final String locale,
  });
}

/// Mock implementation: simulates delay and optional failure for uploads,
/// returns a canned reply for getDealReply.
class MockExpressDealmakerRemoteDataSource implements ExpressDealmakerRemoteDataSource {
  MockExpressDealmakerRemoteDataSource(this._logger);

  final AppLogger _logger;
  static const _uploadDelay = Duration(milliseconds: 2200);
  static const _getReplyDelay = Duration(milliseconds: 1200);

  @override
  Future<UploadScreenshotResultDto> uploadScreenshot(final String filePath) async {
    _logger.i('Mock upload screenshot: $filePath');
    await Future<void>.delayed(_uploadDelay);
    // Mock always succeeds so user can tap Get More and see a reply
    return UploadScreenshotResultDto(id: 'mock_${filePath.hashCode}');
  }

  @override
  Future<DealReplyDto> getDealReply({
    required final List<String> uploadedIds,
    final String? keyword,
    required final String locale,
  }) async {
    _logger.i('Mock getDealReply ids: $uploadedIds keyword: $keyword locale: $locale');
    await Future<void>.delayed(_getReplyDelay);
    final keywordPart = (keyword != null && keyword.isNotEmpty)
        ? ' (keyword: "$keyword")'
        : '';
    // Mock returns different text per locale so backend can do the same.
    final mockOptions = locale.startsWith('es')
        ? [
            "[Mock] ¿Cerramos trato? Prueba: \"He visto otra oferta mejor, ¿puedes igualarla?\"",
            "[Mock] Suave: \"¿Me harías 10% de descuento si pago hoy?\"",
            "[Mock] Seguro: \"Tu competencia lo tiene más barato. ¿Qué puedes hacer?\"",
          ]
        : [
            "[Mock] Tracking this deal? Let's turn it into a win. Try: \"I've seen a better offer elsewhere—can you match it?\"",
            "[Mock] Soft push: \"Would you do 10% off if I pay today?\"",
            "[Mock] Confident: \"Your competitor has it for less. What can you do?\"",
          ];
    return DealReplyDto(
      options: mockOptions.map((t) => '$t$keywordPart').toList(),
    );
  }
}
