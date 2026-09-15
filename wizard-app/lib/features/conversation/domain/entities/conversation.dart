import 'package:equatable/equatable.dart';
import 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

export 'package:appwizard/features/conversation/domain/entities/deal_line.dart';

/// Type discriminator for [Conversation]. Same repository/datasource return all types.
enum ConversationType {
  express,
  proDealCloser,
}

/// Outcome of a saved negotiation (Bargains History filter chips).
enum ConversationStatus {
  open,
  won,
  lost;

  static ConversationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'won':
        return ConversationStatus.won;
      case 'lost':
        return ConversationStatus.lost;
      default:
        return ConversationStatus.open;
    }
  }
}

/// Single message in a Pro Deal Closer conversation.
/// [isWizard] marks assistant messages; [options] holds the "Give me options"
/// lines attached to a wizard reply once requested.
class ProDealCloserMessage extends Equatable {
  const ProDealCloserMessage({
    required this.text,
    this.attachmentPaths = const [],
    this.isWizard = false,
    this.options = const [],
  });

  final String text;
  final List<String> attachmentPaths;
  final bool isWizard;
  final List<DealLine> options;

  /// Convenience inverse of [isWizard].
  bool get isUser => !isWizard;

  ProDealCloserMessage copyWith({
    String? text,
    List<String>? attachmentPaths,
    bool? isWizard,
    List<DealLine>? options,
  }) =>
      ProDealCloserMessage(
        text: text ?? this.text,
        attachmentPaths: attachmentPaths ?? this.attachmentPaths,
        isWizard: isWizard ?? this.isWizard,
        options: options ?? this.options,
      );

  @override
  List<Object?> get props => [text, attachmentPaths, isWizard, options];
}

/// Generic conversation; [type] segregates which fields are used.
/// Stored and returned by the same repository/datasource (e.g. API returns all).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    this.screenshotPaths = const [],
    this.replyOptions = const [],
    this.replyLines = const [],
    this.keyword,
    this.messages = const [],
    required this.createdAt,
    this.title,
    this.marketplace,
    this.status = ConversationStatus.open,
    this.priceBefore,
    this.priceAfter,
    this.seeing,
    this.vibe,
  });

  final String id;
  /// [ConversationType.express] or [ConversationType.proDealCloser]. Drives which payload is used.
  final ConversationType type;
  /// For [ConversationType.express].
  final List<String> screenshotPaths;
  /// Legacy flat reply strings (kept for backward compatibility with saved data).
  final List<String> replyOptions;
  /// Structured reply lines with intent + why. Preferred over [replyOptions].
  final List<DealLine> replyLines;
  final String? keyword;
  /// For [ConversationType.proDealCloser].
  final List<ProDealCloserMessage> messages;
  final DateTime createdAt;

  // ── History metadata (Bargains History screen) ──
  /// Auto-generated from the screenshot / first message when null.
  final String? title;
  final String? marketplace;
  final ConversationStatus status;
  /// Free-form price strings, e.g. "$420" → "$365".
  final String? priceBefore;
  final String? priceAfter;
  /// What the wizard "saw" in the screenshots (Express results strip).
  final String? seeing;
  /// Negotiation vibe id used for this deal (e.g. "friendly").
  final String? vibe;

  /// Effective reply lines: structured when available, else legacy strings.
  List<DealLine> get effectiveLines => replyLines.isNotEmpty
      ? replyLines
      : replyOptions.map((t) => DealLine(text: t)).toList();

  /// First image usable as a thumbnail (express screenshot or a chat attachment).
  String? get thumbnailPath {
    if (screenshotPaths.isNotEmpty) return screenshotPaths.first;
    for (final m in messages) {
      if (m.attachmentPaths.isNotEmpty) return m.attachmentPaths.first;
    }
    return null;
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    List<String>? screenshotPaths,
    List<String>? replyOptions,
    List<DealLine>? replyLines,
    String? keyword,
    List<ProDealCloserMessage>? messages,
    DateTime? createdAt,
    String? title,
    String? marketplace,
    ConversationStatus? status,
    String? priceBefore,
    String? priceAfter,
    String? seeing,
    String? vibe,
  }) =>
      Conversation(
        id: id ?? this.id,
        type: type ?? this.type,
        screenshotPaths: screenshotPaths ?? this.screenshotPaths,
        replyOptions: replyOptions ?? this.replyOptions,
        replyLines: replyLines ?? this.replyLines,
        keyword: keyword ?? this.keyword,
        messages: messages ?? this.messages,
        createdAt: createdAt ?? this.createdAt,
        title: title ?? this.title,
        marketplace: marketplace ?? this.marketplace,
        status: status ?? this.status,
        priceBefore: priceBefore ?? this.priceBefore,
        priceAfter: priceAfter ?? this.priceAfter,
        seeing: seeing ?? this.seeing,
        vibe: vibe ?? this.vibe,
      );

  @override
  List<Object?> get props => [
        id,
        type,
        screenshotPaths,
        replyOptions,
        replyLines,
        keyword,
        messages,
        createdAt,
        title,
        marketplace,
        status,
        priceBefore,
        priceAfter,
        seeing,
        vibe,
      ];
}
