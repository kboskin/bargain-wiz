import 'package:appwizard/core/utils/color_helper.dart';
import 'package:flutter/material.dart';

/// Result of processing a word for highlighting
class WordHighlightResult {
  const WordHighlightResult({
    required this.isHighlight,
    this.wordColor,
    this.matchedWord,
    this.isBold = false,
    this.isBoldLarge = false,
  });

  final bool isHighlight;
  final Color? wordColor;
  final String? matchedWord;
  /// Bold only (e.g. remote config value "bold"); uses highlight_color.
  final bool isBold;
  /// Bold + slightly larger (e.g. remote config value "bold_large").
  final bool isBoldLarge;
}

/// Parsed highlight words configuration
class ParsedHighlightConfig {
  ParsedHighlightConfig({
    required this.words,
    required this.wordColors,
    this.wordBold = const {},
    this.wordBoldLarge = const {},
  });

  final List<String> words;
  final Map<String, Color> wordColors;
  final Set<String> wordBold;
  final Set<String> wordBoldLarge;
}

/// Helper class for processing text with word highlighting
/// Extracts duplicate logic for finding and highlighting words in text
class TextHighlightHelper {
  TextHighlightHelper(this._colorHelper);

  final ColorHelper _colorHelper;

  /// Parse highlight words data (supports map or list format)
  /// Map format: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4", "Studies reveal": "bold", "YOU": "bold_large"}
  /// List format: ["Bargain", "Wiz"] - backward compatibility
  ParsedHighlightConfig parseHighlightWords(
    final dynamic highlightWordsData,
  ) {
    final wordColors = <String, Color>{};
    final highlightWords = <String>[];
    final wordBold = <String>{};
    final wordBoldLarge = <String>{};

    if (highlightWordsData is Map) {
      highlightWordsData.forEach((final word, final value) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (value is String) {
          final lower = value.toLowerCase().trim();
          if (lower == 'bold') {
            wordBold.add(wordStr.toLowerCase());
          } else if (lower == 'bold_large') {
            wordBoldLarge.add(wordStr.toLowerCase());
          } else {
            final color = _colorHelper.getColor(value);
            if (color != null) {
              wordColors[wordStr.toLowerCase()] = color;
            }
          }
        }
      });
    } else if (highlightWordsData is List) {
      highlightWords.addAll(
        highlightWordsData.map((final item) => item.toString()),
      );
    }

    return ParsedHighlightConfig(
      words: highlightWords,
      wordColors: wordColors,
      wordBold: wordBold,
      wordBoldLarge: wordBoldLarge,
    );
  }

  /// Check if a word should be highlighted and get its color
  /// Returns WordHighlightResult with highlight status and color
  WordHighlightResult processWord(
    final String word,
    final ParsedHighlightConfig config,
    final Color? defaultHighlightColor,
  ) {
    final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

    // Find matching highlight word
    String? matchedWord;
    for (final hw in config.words) {
      final cleanHw = hw.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (cleanWord.contains(cleanHw) || cleanHw.contains(cleanWord)) {
        matchedWord = hw;
        break;
      }
    }

    final isHighlight = matchedWord != null;
    final key = matchedWord?.toLowerCase();
    final wordColor = isHighlight
        ? (config.wordColors[key] ?? defaultHighlightColor)
        : defaultHighlightColor;
    final isBold = key != null && config.wordBold.contains(key);
    final isBoldLarge = key != null && config.wordBoldLarge.contains(key);

    return WordHighlightResult(
      isHighlight: isHighlight,
      wordColor: wordColor,
      matchedWord: matchedWord,
      isBold: isBold,
      isBoldLarge: isBoldLarge,
    );
  }
}

