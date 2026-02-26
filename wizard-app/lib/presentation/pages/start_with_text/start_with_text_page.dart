import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:appwizard/core/theme/app_colors.dart';
import 'package:appwizard/core/theme/app_text_styles.dart';
import 'package:appwizard/core/routing/app_routes.dart';

/// Chat-style "Start with text" screen: input at top, AI suggestion bubbles
/// that appear to stack from the bottom, with a persistent bottom action bar.
class StartWithTextPage extends StatefulWidget {
  const StartWithTextPage({super.key});

  @override
  State<StartWithTextPage> createState() => _StartWithTextPageState();
}

class _StartWithTextPageState extends State<StartWithTextPage> {
  final TextEditingController _focusController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Suggestions in order [oldest ... newest]. Newest is shown at bottom (reverse list).
  final List<String> _suggestions = [];

  /// Optional: seed with a couple of placeholders to show the "from bottom" effect
  @override
  void initState() {
    super.initState();
    // Uncomment to show example bubbles: _suggestions.addAll(_placeholderSuggestions);
  }

  static const List<String> _placeholderSuggestions = [
    '⚡ Something that makes my heart race—how about a partner in crime for some mischievous adventures?',
    '⚡ Just a partner in crime and fun adventures!',
    "⚡ Hey, I'm just hunting for trouble... care to join me on a thrilling adventure or are you more of a safe bet? 😉",
  ];

  @override
  void dispose() {
    _focusController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
          color: AppColors.textPrimary,
        ),
        centerTitle: true,
        title: Text(
          'Deal lines',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prompt + input section (fixed at top)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPromptBubble(context),
                  const SizedBox(height: 12),
                  _buildFocusInput(context),
                  const SizedBox(height: 8),
                  _buildHint(context),
                ],
              ),
            ),
            // Chat bubbles area: reverse list so newest stays at bottom; content appears "scrolled from bottom"
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 12,
                      bottom: 100, // Space for bottom bar overlay so last bubble is partially hidden
                    ),
                    itemCount: _suggestions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _suggestions.length) {
                        // Spacer so when there are few items they sit near the bottom
                        return const SizedBox(height: 120);
                      }
                      final text = _suggestions[_suggestions.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SuggestionBubble(text: text),
                      );
                    },
                  ),
                  _buildBottomBar(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          "What's the deal about?",
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildFocusInput(BuildContext context) {
    return TextField(
      controller: _focusController,
      decoration: InputDecoration(
        hintText: 'Give us a word or two to focus on',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      onSubmitted: (_) => _onGenerate(),
    );
  }

  Widget _buildHint(BuildContext context) {
    return Center(
      child: Text(
        '⚡ hold a reply for more ⚡',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onGenerate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: Text(
              'Generate deal lines',
              style: AppTextStyles.buttonText.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  void _onGenerate() {
    final focus = _focusController.text.trim();
    // TODO: Call API / BLoC to generate deal lines; for now add a placeholder
    setState(() {
      _suggestions.add(
        '⚡ ${focus.isEmpty ? "Here\'s a line for you" : "Deal line for: $focus"} — try holding for more!',
      );
    });
  }
}

class _SuggestionBubble extends StatelessWidget {
  const _SuggestionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
