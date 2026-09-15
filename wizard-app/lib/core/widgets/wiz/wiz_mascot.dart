import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';

/// Wizard mascot cut-out (assets/images/wizard_cutout.png, 558×678, transparent).
class WizMascot extends StatelessWidget {
  const WizMascot({
    super.key,
    this.width = 180,
    this.greyscale = false,
    this.opacity = 1,
  });

  static const String asset = 'assets/images/wizard_cutout.png';

  final double width;
  final bool greyscale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(asset, width: width, fit: BoxFit.contain);
    if (greyscale) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: img,
      );
    }
    if (opacity < 1) img = Opacity(opacity: opacity, child: img);
    return img;
  }
}

/// Mascot on a yellow disc (welcome hero, paywall intro).
class WizMascotOnDisc extends StatelessWidget {
  const WizMascotOnDisc({
    super.key,
    this.discSize = 180,
    this.mascotWidth = 180,
    this.discColor = WizColors.yellow,
  });

  final double discSize;
  final double mascotWidth;
  final Color discColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: discSize * 1.2,
        height: discSize * 1.2,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: discSize,
                height: discSize,
                decoration: BoxDecoration(color: discColor, shape: BoxShape.circle),
              ),
            ),
            WizMascot(width: mascotWidth),
          ],
        ),
      );
}

/// 30px avatar: yellow circle with the mascot face centred (image 2.4× the circle, offset -45% height).
class WizAvatar extends StatelessWidget {
  const WizAvatar({super.key, this.size = 30, this.color = WizColors.yellow});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Container(
          width: size,
          height: size,
          color: color,
          child: OverflowBox(
            maxWidth: size * 2.4,
            maxHeight: size * 2.4 * (678 / 558),
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -size * 0.45),
              child: Image.asset(WizMascot.asset, width: size * 2.4, fit: BoxFit.contain),
            ),
          ),
        ),
      );
}

/// Brand row: 22px purple circle with yellow "%" + "Bargain Wiz".
class WizBrandRow extends StatelessWidget {
  const WizBrandRow({super.key, this.title = 'Bargain Wiz', this.size = 22, this.textStyle});

  final String title;
  final double size;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: WizColors.purple, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '%',
              style: TextStyle(
                fontFamily: WizType.display,
                fontSize: size * 0.6,
                fontWeight: FontWeight.w700,
                color: WizColors.yellow,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: textStyle ??
                const TextStyle(
                  fontFamily: WizType.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WizColors.ink,
                ),
          ),
        ],
      );
}
