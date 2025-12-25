import 'package:appwizard/core/utils/color_helper.dart';
import 'package:flutter/material.dart';

/// Result of processing a word for highlighting
class WordHighlightResult {
  const WordHighlightResult({
    required this.isHighlight,
    this.wordColor,
    this.matchedWord,
  });

  final bool isHighlight;
  final Color? wordColor;
  final String? matchedWord;
}

/// Parsed highlight words configuration
class HighlightWordsConfig {
  HighlightWordsConfig({
    required this.words,
    required this.wordColors,
  });

  final List<String> words;
  final Map<String, Color> wordColors;
}

/// Helper class for processing text with word highlighting
/// Extracts duplicate logic for finding and highlighting words in text
class TextHighlightHelper {
  TextHighlightHelper(this._colorHelper);

  final ColorHelper _colorHelper;

  /// Parse highlight words data (supports map or list format)
  /// Map format: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
  /// List format: ["Bargain", "Wiz"] - backward compatibility
  HighlightWordsConfig parseHighlightWords(
    final dynamic highlightWordsData,
  ) {
    final wordColors = <String, Color>{};
    final highlightWords = <String>[];

    if (highlightWordsData is Map) {
      // Map format: {"Bargain": "#FF6B35", "Wiz": "#4ECDC4"}
      highlightWordsData.forEach((final word, final colorValue) {
        final wordStr = word.toString();
        highlightWords.add(wordStr);
        if (colorValue is String) {
          final color = _colorHelper.getColor(colorValue);
          if (color != null) {
            wordColors[wordStr.toLowerCase()] = color;
          }
        }
      });
    } else if (highlightWordsData is List) {
      // List format: ["Bargain", "Wiz"] - backward compatibility
      highlightWords.addAll(
        highlightWordsData.map((final item) => item.toString()),
      );
    }

    return HighlightWordsConfig(
      words: highlightWords,
      wordColors: wordColors,
    );
  }

  /// Check if a word should be highlighted and get its color
  /// Returns WordHighlightResult with highlight status and color
  WordHighlightResult processWord(
    final String word,
    final HighlightWordsConfig config,
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
    final wordColor = isHighlight
        ? (config.wordColors[matchedWord.toLowerCase()] ?? defaultHighlightColor)
        : defaultHighlightColor;

    return WordHighlightResult(
      isHighlight: isHighlight,
      wordColor: wordColor,
      matchedWord: matchedWord,
    );
  }
}

