import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen {
  final String title;
  final String description;
  final IconData icon;

  OnboardingScreen({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingScreen> _screens = [
    OnboardingScreen(
      title: 'Be a Deal God',
      description: 'Master the art of bargaining. Get the best prices on Facebook Marketplace and never overpay.',
      icon: Icons.local_offer,
    ),
    OnboardingScreen(
      title: 'Smart Screenshot Analysis',
      description: 'Upload conversation screenshots. Our on-device OCR extracts everything and helps you craft perfect replies.',
      icon: Icons.chat_bubble_outline,
    ),
    OnboardingScreen(
      title: 'AI Negotiation Superpower',
      description: 'Get instant reply suggestions that help you negotiate like a pro and close deals at unbeatable prices.',
      icon: Icons.auto_awesome,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    if (_currentPage < _screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to home after onboarding
      context.go('/');
    }
  }

  void _skipOnboarding() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // PageView for onboarding screens
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _screens.length,
                itemBuilder: (context, index) {
                  final screen = _screens[index];
                  return _buildOnboardingScreen(screen);
                },
              ),
            ),

            // Page indicators and next button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _screens.length,
                      (index) => _buildPageIndicator(index == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next/Get Started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == _screens.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingScreen(OnboardingScreen screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              screen.icon,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),

          // Title with styled text
          _buildStyledTitle(context, screen.title),
          const SizedBox(height: 24),

          // Description with styled text
          _buildStyledDescription(context, screen.description),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStyledTitle(BuildContext context, String title) {
    // Check if title contains "Deal God" or "bargain"
    if (title.contains('Deal God')) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
          children: const [
            TextSpan(text: 'Be a '),
            TextSpan(
              text: 'Deal God',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 36,
                shadows: [
                  Shadow(
                    color: Colors.amber,
                    blurRadius: 20,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStyledDescription(BuildContext context, String description) {
    // Check for keywords to style
    final hasBargain = description.toLowerCase().contains('bargain');
    final hasBargaining = description.toLowerCase().contains('bargaining');
    final hasDeal = description.toLowerCase().contains('deal');
    final hasBest = description.toLowerCase().contains('best');
    
    if (hasBargain || hasBargaining || hasDeal || hasBest) {
      final matches = RegExp(r'\b(bargain|bargaining|deal|best)\b', caseSensitive: false).allMatches(description);
      
      final spans = <TextSpan>[];
      int lastIndex = 0;
      
      for (final match in matches) {
        // Add text before match
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: description.substring(lastIndex, match.start),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.5,
                  fontSize: 16,
                ),
          ));
        }
        
        // Add styled match
        spans.add(TextSpan(
          text: description.substring(match.start, match.end),
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1.5,
            shadows: [
              Shadow(
                color: Colors.amber.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ));
        
        lastIndex = match.end;
      }
      
      // Add remaining text
      if (lastIndex < description.length) {
        spans.add(TextSpan(
          text: description.substring(lastIndex),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
                fontSize: 16,
              ),
        ));
      }
      
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: spans),
      );
    }
    
    return Text(
      description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.5,
            fontSize: 16,
          ),
      textAlign: TextAlign.center,
    );
  }
}

