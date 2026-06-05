import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shiftchart/screens/main_screen.dart';
import 'package:shiftchart/theme/AppColors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late bool isReview;

  @override
  void initState() {
    super.initState();
    isReview = Hive.box(
      'settings',
    ).get('hasSeenOnboarding', defaultValue: false);
  }

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Streamline Your Shift',
      description:
          'Replace paper-based workflows with a focused clinical tracker. Manage medications, IV infusions, and critical tasks in one place.',
      icon: Icons.speed_outlined,
    ),
    OnboardingItem(
      title: 'Precise Handovers',
      description:
          'Generate structured HPR clinical summaries in seconds. Select and share patient data for safer, more informed shift transitions.',
      icon: Icons.assignment_turned_in_outlined,
    ),
    OnboardingItem(
      title: 'Focus on Patient Care',
      description:
          'Receive timely reminders for due medications and overdue tasks. Less time on documentation, more time at the bedside.',
      icon: Icons.medical_services_outlined,
    ),
  ];

  void _finishOnboarding() async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('hasSeenOnboarding', true);
    final nurseName = Hive.box('settings').get('nurseName', defaultValue: '');
    if (nurseName.isEmpty) {
      _showNameDialog();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppDurations.slow,
      ),
    );
  }

  void _showNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Your Name',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Used for clinical audit records and shift reports. Never shared or transmitted.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Sarah K.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await Hive.box('settings').put('nurseName', name);
              if (!mounted) return;
              Navigator.pop(context);
              _finishOnboarding();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return OnboardingPage(item: _items[index]);
            },
          ),

          // Navigation UI
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _items.length,
                    (index) => AnimatedContainer(
                      duration: AppDurations.fast,
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: isLastPage ? 'Get Started' : 'Next',
                  onTap: () {
                    if (_currentPage < _items.length - 1) {
                      if (AppDurations.reduceMotion) {
                        _pageController.jumpToPage(_currentPage + 1);
                      } else {
                        _pageController.nextPage(
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                        );
                      }
                    } else {
                      if (isReview) {
                        Navigator.pop(context);
                      } else {
                        _finishOnboarding();
                      }
                    }
                  },
                ),
                AnimatedSwitcher(
                  duration: AppDurations.normal,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1.0,
                            child: child,
                          ),
                        );
                      },
                  switchInCurve: Curves.easeOutCubic,

                  child: isLastPage
                      ? const SizedBox.shrink()
                      : Padding(
                          key: const ValueKey('skip_button'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              TextButton(
                                onPressed: isReview
                                    ? () => Navigator.pop(context)
                                    : _finishOnboarding,
                                child: Text(
                                  isReview ? 'Close' : "Skip",
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingItem item;

  const OnboardingPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 160),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 3),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 100, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 48),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
