/// Builds the text handed to the native share sheet: non-empty, trimmed parts
/// (title, description, link) joined with blank lines. Pure; no Flutter / DI imports.
String composeShareMessage({String? title, String? description, String? link}) {
  final parts = <String>[
    for (final p in [title, description, link])
      if (p != null && p.trim().isNotEmpty) p.trim(),
  ];
  return parts.join('\n\n');
}
