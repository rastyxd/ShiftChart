import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shiftchart/screens/patient_list_screen.dart';
import 'package:shiftchart/screens/meds_overview_screen.dart';
import 'package:shiftchart/screens/settings_screen.dart';
import 'package:shiftchart/screens/tasks_overview_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shiftchart/theme/AppColors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _settingsBox = Hive.box('settings');

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          toolbarHeight: 80,
          titleSpacing: 20,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              SvgPicture.asset(
                'assets/brand/logo.svg',
                height: 32,
                width: 32,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ShiftChart',
                style: GoogleFonts.manrope(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
                onPressed: () => _showQuickSettings(context),
              ),
            ),
          ],
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: reduceMotionNotifier,
          builder: (context, reduceMotion, _) {
            return TabBarView(
              physics: reduceMotion ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              children: const [
                PatientListScreen(),
                MedsOverviewScreen(),
                TasksOverviewScreen(),
              ],
            );
          },
        ),
        bottomNavigationBar: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController.animation!,
              builder: (context, child) {
                final double value = tabController.animation!.value;
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Stack(
                    children: [
                      // Top indicator line
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: CustomPaint(
                          painter: _NavIndicatorPainter(
                            value,
                            3,
                            Theme.of(context).colorScheme.primary,
                          ),
                          size: const Size.fromHeight(1),
                        ),
                      ),
                      // Custom Navigation Items
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: Row(
                          children: [
                            _buildNavItem(context, 0, 'Patients', Icons.people_outline, Icons.people, value),
                            _buildNavItem(context, 1, 'Meds', Icons.medication_outlined, Icons.medication, value),
                            _buildNavItem(context, 2, 'Tasks', Icons.assignment_outlined, Icons.assignment, value),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showNotificationModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Mode',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _buildPickerOption(context, NotificationMode.on, 'On', 'Sound and vibration enabled', Icons.notifications_active_outlined),
            _buildPickerOption(context, NotificationMode.vibrate, 'Vibrate Only', 'No sound, haptics only', Icons.vibration_outlined),
            _buildPickerOption(context, NotificationMode.off, 'Off', 'All notifications silenced', Icons.notifications_off_outlined),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(BuildContext context, NotificationMode mode, String title, String subtitle, IconData icon) {
    return ValueListenableBuilder<NotificationMode>(
      valueListenable: notificationModeNotifier,
      builder: (context, currentMode, child) {
        final isSelected = currentMode == mode;
        return ListTile(
          onTap: () {
            notificationModeNotifier.value = mode;
            Hive.box('settings').put('notificationMode', mode.name);
            Navigator.pop(context);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
        );
      },
    );
  }

  void _showQuickSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickToggle(
              context,
              icon: '🌙',
              label: 'Theme',
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, child) {
                  return Switch(
                    value: mode == ThemeMode.dark,
                    onChanged: (isDark) {
                      final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
                      themeNotifier.value = newMode;
                      _settingsBox.put('themeMode', isDark ? 'dark' : 'light');
                    },
                  );
                },
              ),
            ),
            _buildQuickToggle(
              context,
              icon: '🔔',
              label: 'Notifications',
              trailing: ValueListenableBuilder<NotificationMode>(
                valueListenable: notificationModeNotifier,
                builder: (context, mode, child) {
                  return GestureDetector(
                    onTap: () => _showNotificationModePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mode.name.toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _buildQuickToggle(
              context,
              icon: '👁️',
              label: 'Eye Comfort',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: eyeComfortNotifier,
                builder: (context, isEnabled, child) {
                  return Switch(
                    value: isEnabled,
                    onChanged: (v) {
                      eyeComfortNotifier.value = v;
                      _settingsBox.put('eyeComfort', v);
                    },
                  );
                },
              ),
            ),
            _buildQuickToggle(
              context,
              icon: '💨',
              label: 'Reduce Motion',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: reduceMotionNotifier,
                builder: (context, isEnabled, child) {
                  return Switch(
                    value: isEnabled,
                    onChanged: (v) {
                      reduceMotionNotifier.value = v;
                      _settingsBox.put('reduceMotion', v);
                    },
                  );
                },
              ),
            ),
            Divider(height: 32, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToggle(BuildContext context, {required String icon, required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text(icon, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, String label, IconData icon, IconData selectedIcon, double value) {
    final double distance = (value - index).abs();
    final double t = (1.0 - distance).clamp(0.0, 1.0);
    final Color selectedColor = Theme.of(context).colorScheme.primary;
    final Color unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final Color color = Color.lerp(unselectedColor, selectedColor, t)!;

    return Expanded(
      child: ValueListenableBuilder<bool>(
        valueListenable: reduceMotionNotifier,
        builder: (context, reduceMotion, _) {
          return GestureDetector(
            onTap: () {
              if (reduceMotion) {
                DefaultTabController.of(context).index = index;
              } else {
                DefaultTabController.of(context).animateTo(index);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t > 0.5 ? selectedIcon : icon, color: color, size: 26),
                const SizedBox(height: 4),
                Opacity(
                  opacity: reduceMotion ? (t > 0.5 ? 1.0 : 0.0) : t,
                  child: Transform.translate(
                    offset: Offset(0, reduceMotion ? 0 : (1 - t) * 4),
                    child: Text(
                      label,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavIndicatorPainter extends CustomPainter {
  final double value;
  final int count;
  final Color color;

  _NavIndicatorPainter(this.value, this.count, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final double itemWidth = size.width / count;
    final double baseWidth = itemWidth * 0.6;
    final double clampedValue = value.clamp(0.0, (count - 1).toDouble());
    
    // Check reduce motion via the global notifier directly in paint if needed, 
    // but better to pass it in or handle it via value logic.
    // For now, let's keep it simple: if reduceMotion is on, we skip the "stretch" effect.
    
    final bool reduceMotion = reduceMotionNotifier.value;

    if (reduceMotion) {
      final int index = clampedValue.round();
      final double left = (index * itemWidth) + (itemWidth / 2) - (baseWidth / 2);
      final double right = left + baseWidth;
      canvas.drawRRect(RRect.fromLTRBAndCorners(left, 0, right, 2.5, bottomLeft: Radius.zero, bottomRight: Radius.zero), paint);
      return;
    }

    final double fraction = clampedValue % 1.0;
    final int index = clampedValue.floor();
    double left, right;
    if (fraction < 0.5) {
      left = (index * itemWidth) + (itemWidth / 2) - (baseWidth / 2);
      double t = fraction * 2;
      right = left + baseWidth + (t * itemWidth);
    } else {
      right = ((index + 1) * itemWidth) + (itemWidth / 2) + (baseWidth / 2);
      double t = (fraction - 0.5) * 2;
      left = (index * itemWidth) + (itemWidth / 2) - (baseWidth / 2) + (t * itemWidth);
    }
    canvas.drawRRect(RRect.fromLTRBAndCorners(left, 0, right, 2.5, bottomLeft: Radius.zero, bottomRight: Radius.zero), paint);
  }

  @override
  bool shouldRepaint(_NavIndicatorPainter oldDelegate) => value != oldDelegate.value;
}


