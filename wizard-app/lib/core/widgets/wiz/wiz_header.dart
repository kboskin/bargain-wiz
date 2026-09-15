import 'package:flutter/material.dart';
import 'package:appwizard/core/theme/wiz_theme.dart';
import 'package:appwizard/core/widgets/wiz/wiz_buttons.dart';

/// 48px screen header: back chevron · centred Outfit 17/600 title · optional trailing widget.
class WizHeader extends StatelessWidget implements PreferredSizeWidget {
  const WizHeader({
    super.key,
    required this.title,
    this.onBack,
    this.leading,
    this.trailing,
    this.height = 48,
    this.horizontalPadding = WizSpacing.gutter,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double horizontalPadding;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final lead = leading ?? (onBack != null ? WizBackChevron(onPressed: onBack) : null);
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WizType.appBarTitle,
                ),
              ),
            ),
            if (lead != null) Align(alignment: Alignment.centerLeft, child: lead),
            if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    );
  }
}
