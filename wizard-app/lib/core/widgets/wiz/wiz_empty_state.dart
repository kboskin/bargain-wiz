import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Empty-list placeholder: illustration (wizard beside an empty chest by default) + title + body.
class WizEmptyState extends StatelessWidget {
  const WizEmptyState({
    required this.title,
    required this.body,
    super.key,
    this.image = defaultImage,
    this.imageWidth = 160,
  });

  /// 560×672, transparent.
  static const String defaultImage = 'assets/images/empty_state_cutout.png';

  final String title;
  final String body;
  final String image;
  final double imageWidth;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(image, width: imageWidth, fit: BoxFit.contain),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: WizType.sectionTitle),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center, style: WizType.bodySm),
          ],
        ),
      );
}
