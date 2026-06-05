import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/audit_log_screen.dart';
import 'package:shiftchart/screens/hpr_history_screen.dart';
import 'package:shiftchart/screens/onboarding_screen.dart';
import 'package:shiftchart/screens/saved_records_screen.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/auth_service.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E10) : const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 80,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(top: 20, left: 12),
          child: IconButton(
            icon: Icon(Icons.arrow_back, 
                       color: Theme.of(context).colorScheme.onSurface,
                       size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            'Settings',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          _buildGroup(context, [
            _buildMenuTile(
              context, 
              'Appearance & Visuals', 
              Icons.palette_outlined,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _AppearanceSettings())),
            ),
            _buildMenuTile(
              context, 
              'Accessibility', 
              Icons.accessibility_new_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _AccessibilitySettings())),
            ),
            _buildMenuTile(
              context, 
              'Security & Privacy', 
              Icons.lock_outline_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _SecuritySettings())),
            ),
            _buildMenuTile(
              context, 
              'Localization & Time', 
              Icons.language_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _LocalizationSettings())),
            ),
            _buildMenuTile(
              context, 
              'Alerts & Notifications', 
              Icons.notifications_none_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _NotificationSettings())),
            ),
          ]),

          _buildSectionHeader('System'),
          _buildGroup(context, [
            _buildMenuTile(
              context, 
              'Data & History', 
              Icons.storage_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _DataSettings())),
            ),
            _buildMenuTile(
              context, 
              'Support & Legal', 
              Icons.help_outline_rounded,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const _SupportSettings())),
            ),
          ]),

          const SizedBox(height: 24),
          _buildGroup(context, [
            _buildActionTile(
              context,
              'Clear All Data',
              textColor: Theme.of(context).colorScheme.error,
              showChevron: false,
              onTap: () => _showClearDataDialog(context),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Clear All Data?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text(
            'This will permanently delete all patient records, medications, tasks, and application settings. This action is irreversible and cannot be undone.',
          style: GoogleFonts.manrope(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.manrope()),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Clear Boxes
                await Hive.box<Patient>('patients').clear();
                await Hive.box<Medication>('medications').clear();
                await Hive.box('settings').clear();

                AuditService.log(AuditAction.allDataCleared, {
                  'reason': 'User requested full reset'
                }, outcome: true);

                // Reset Notifiers
                themeNotifier.value = ThemeMode.dark;
                eyeComfortNotifier.value = false;
                notificationModeNotifier.value = NotificationMode.on;

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('All data has been cleared', style: GoogleFonts.manrope()),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              } catch (e) {
                AuditService.log(AuditAction.allDataCleared, {
                  'error': e.toString()
                }, outcome: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error clearing data: $e')),
                  );
                }
              }
            },
            child: Text('Clear All', style: GoogleFonts.manrope(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  Widget _buildMenuTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  static Widget _buildGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final idx = entry.key;
          final widget = entry.value;
          return Column(
            children: [
              widget,
              if (idx < children.length - 1)
                Divider(
                  height: 1,
                  indent: 54, // Adjusted for icons
                  endIndent: 0,
                  thickness: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildActionTile(BuildContext context, String title, {String? trailing, String? subtitle, VoidCallback? onTap, Color? textColor, bool showChevron = true}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor ?? Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildToggleTile(BuildContext context, String title, ValueNotifier notifier, void Function(bool)? onChanged) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        final bool isSelected = value is bool ? value : (value is ThemeMode ? value == ThemeMode.dark : false);
        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 12, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Switch.adaptive(
                value: isSelected,
                onChanged: onChanged,
                activeColor: const Color(0xFF91C49B),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSubPage({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E10) : const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 80,
        centerTitle: false,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(top: 20, left: 12),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsScreen._buildGroup(context, children),
        ],
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings();

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<AppThemeName>(
        title: 'Select Theme',
        notifier: appThemeNotifier,
        options: [
          _PickerOption(AppThemeName.defaultTheme, 'ShiftChart Default', 'The signature clean look', Icons.auto_awesome),
          _PickerOption(AppThemeName.pinky, 'Pinky', 'Soft and vibrant tones', Icons.favorite),
          _PickerOption(AppThemeName.hero, 'Hero', 'Action-oriented blue and gold', Icons.bolt),
          _PickerOption(AppThemeName.batman, 'Batman', 'Deep dark with yellow highlights', Icons.dark_mode),
        ],
        onSelect: (name) {
          appThemeNotifier.value = name;
          Hive.box('settings').put('appThemeName', name.name);
        },
      ),
    );
  }

  void _showAccentPicker(BuildContext context) {
    final colors = [
      const Color(0xFF91C49B), // Default Green
      const Color(0xFF7E57C2), // Purple
      const Color(0xFFEF5350), // Red
      const Color(0xFF42A5F5), // Blue
      const Color(0xFFFFA726), // Orange
      const Color(0xFF26A69A), // Teal
    ];

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accent Color',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only applies to the Default theme',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: colors.map((color) => GestureDetector(
                onTap: () {
                  accentColorNotifier.value = color;
                  Hive.box('settings').put('accentColor', color.value);
                  Navigator.pop(context);
                },
                child: ValueListenableBuilder<Color>(
                  valueListenable: accentColorNotifier,
                  builder: (context, current, _) {
                    final isSelected = current.value == color.value;
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    );
                  }
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Appearance & Visuals',
      children: [
        ValueListenableBuilder<AppThemeName>(
          valueListenable: appThemeNotifier,
          builder: (context, name, _) {
            final label = switch (name) {
              AppThemeName.defaultTheme => 'ShiftChart Default',
              AppThemeName.pinky => 'Pinky',
              AppThemeName.hero => 'Hero',
              AppThemeName.batman => 'Batman',
            };
            return SettingsScreen._buildActionTile(
              context, 
              'Theme', 
              trailing: label,
              onTap: () => _showThemePicker(context),
            );
          }
        ),
        ValueListenableBuilder<AppThemeName>(
          valueListenable: appThemeNotifier,
          builder: (context, name, _) {
            final isDefault = name == AppThemeName.defaultTheme;
            return SettingsScreen._buildActionTile(
              context, 
              'Accent Color', 
              textColor: isDefault ? null : Colors.grey[500],
              showChevron: isDefault,
              onTap: isDefault ? () => _showAccentPicker(context) : null,
            );
          }
        ),
        SettingsScreen._buildToggleTile(context, 'Dark Mode', themeNotifier, (v) {
          themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
          Hive.box('settings').put('themeMode', v ? 'dark' : 'light');
        }),
      ],
    );
  }
}

class _PickerOption<T> {
  final T value;
  final String title;
  final String subtitle;
  final IconData icon;
  _PickerOption(this.value, this.title, this.subtitle, this.icon);
}

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final ValueNotifier<T> notifier;
  final List<_PickerOption<T>> options;
  final Function(T) onSelect;

  const _PickerSheet({
    required this.title,
    required this.notifier,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          ...options.map((opt) => _buildOption(context, opt)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, _PickerOption<T> opt) {
    return ValueListenableBuilder<T>(
      valueListenable: notifier,
      builder: (context, current, _) {
        final isSelected = current == opt.value;
        return ListTile(
          onTap: () {
            onSelect(opt.value);
            Navigator.pop(context);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(opt.icon, color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          title: Text(opt.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(opt.subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
        );
      },
    );
  }
}

class _AccessibilitySettings extends StatelessWidget {
  const _AccessibilitySettings();
  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Accessibility',
      children: [
        SettingsScreen._buildToggleTile(context, 'Eye Comfort', eyeComfortNotifier, (v) {
          eyeComfortNotifier.value = v;
          Hive.box('settings').put('eyeComfort', v);
        }),
        SettingsScreen._buildToggleTile(context, 'Reduce Motion', reduceMotionNotifier, (v) {
          reduceMotionNotifier.value = v;
          Hive.box('settings').put('reduceMotion', v);
        }),
      ],
    );
  }
}

class _LocalizationSettings extends StatelessWidget {
  const _LocalizationSettings();
  void _showSafetyWarning(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false, // Prevents accidental swipes
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Header
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Time Format Safety',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Body Text
              Text(
                'The 24-hour format is the established clinical standard and significantly reduces the risk of medication timing errors associated with AM/PM notation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              // Actions
              Column(
                children: [
                  PrimaryButton(
                    onTap: () {
                      use24HourFormatNotifier.value = true;
                      Hive.box('settings').put('use24HourFormat', true);
                      Navigator.pop(context);
                    },
                    label: 'Use 24-Hour Format (Recommended)',
                    width: double.infinity,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Continue with 12-Hour',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<String>(
        title: 'Select Language',
        notifier: languageNotifier,
        options: [
          _PickerOption('English', 'English', 'Clinical Standard (United States)', Icons.language_rounded),
        ],
        onSelect: (lang) {
          languageNotifier.value = lang;
          Hive.box('settings').put('language', lang);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Localization & Time',
      children: [
        ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, lang, _) {
            return SettingsScreen._buildActionTile(
              context, 
              'Language', 
              trailing: lang,
              onTap: () => _showLanguagePicker(context),
            );
          }
        ),
        SettingsScreen._buildToggleTile(
          context, 
          'Use 24h Time Format', 
          use24HourFormatNotifier, 
          (v) {
            use24HourFormatNotifier.value = v;
            Hive.box('settings').put('use24HourFormat', v);
            
            AuditService.log(AuditAction.settingsChanged, {
              'setting': 'use24HourFormat',
              'value': v,
            });

            if (!v) {
              _showSafetyWarning(context);
            }
          },
        ),
      ],
    );
  }
}

class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings();

  void _showNotificationModePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<NotificationMode>(
        title: 'Notification Mode',
        notifier: notificationModeNotifier,
        options: [
          _PickerOption(NotificationMode.on, 'On', 'Sound and vibration enabled', Icons.notifications_active_outlined),
          _PickerOption(NotificationMode.vibrate, 'Vibrate Only', 'No sound, haptics only', Icons.vibration_outlined),
          _PickerOption(NotificationMode.off, 'Off', 'All notifications silenced', Icons.notifications_off_outlined),
        ],
        onSelect: (mode) {
          notificationModeNotifier.value = mode;
          Hive.box('settings').put('notificationMode', mode.name);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Alerts & Notifications',
      children: [
        ValueListenableBuilder<NotificationMode>(
          valueListenable: notificationModeNotifier,
          builder: (context, mode, _) {
            final label = mode == NotificationMode.vibrate ? 'Vibrate Only' : mode.name[0].toUpperCase() + mode.name.substring(1);
            return SettingsScreen._buildActionTile(
              context, 
              'Notification Mode', 
              trailing: label,
              onTap: () => _showNotificationModePicker(context),
            );
          }
        ),
      ],
    );
  }
}

class _DataSettings extends StatelessWidget {
  const _DataSettings();
  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Data & History',
      children: [
        SettingsScreen._buildActionTile(
          context, 
          'HPR (Patient History)',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HPRHistoryScreen()),
          ),
        ),
        SettingsScreen._buildActionTile(
          context, 
          'Saved PDF Records',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedRecordsScreen()),
          ),
        ),
        SettingsScreen._buildActionTile(
          context, 
          'Audit Log',
          subtitle: 'Internal traceability records',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuditLogScreen()),
          ),
        ),
        SettingsScreen._buildActionTile(context, 'Export Shift History'),
      ],
    );
  }
}

class _SecuritySettings extends StatefulWidget {
  const _SecuritySettings();
  @override
  State<_SecuritySettings> createState() => _SecuritySettingsState();
}


class _SecuritySettingsState extends State<_SecuritySettings> {
  final ValueNotifier<bool> _biometricNotifier = ValueNotifier(false);
  bool _isHardwareSupported = false;
  void _showNameEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: Hive.box('settings').get('nurseName', defaultValue: ''),
    );
    showDialog(
      context: context,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await Hive.box('settings').put('nurseName', name);
              
              AuditService.log(AuditAction.settingsChanged, {
                'setting': 'nurseName',
                'value': name,
              });

              if (!context.mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settingsBox = Hive.box('settings');
    _biometricNotifier.value = settingsBox.get('useBiometrics', defaultValue: false);
    _isHardwareSupported = await AuthService().canCheckBiometrics();
    if (mounted) setState(() {});
  }

  void _handleBiometricToggle(bool v) async {
    if (v) {
      // Verify immediately before enabling
      final authenticated = await AuthService().authenticate();
      if (authenticated) {
        _biometricNotifier.value = true;
        await AuthService().setBiometricsEnabled(true);
      }
    } else {
      _biometricNotifier.value = false;
      await AuthService().setBiometricsEnabled(false);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Security & Privacy',
      children: [
        if (!_isHardwareSupported)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Biometric authentication is not supported or not set up on this device.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        SettingsScreen._buildToggleTile(
          context, 
          'Use Biometric Unlock', 
          _biometricNotifier, 
          _isHardwareSupported ? _handleBiometricToggle : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            'Biometric authentication adds an additional layer of security to your patient records. When enabled, fingerprint or face recognition will be required each time you access the app.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SettingsScreen._buildActionTile(
          context,
          'Your Name',
          subtitle: Hive.box('settings').get('nurseName', defaultValue: 'Not set'),
          onTap: () => _showNameEditDialog(context),
        ),
      ],
    );
  }
}

class _SupportSettings extends StatelessWidget {
  const _SupportSettings();

  void _showContent(BuildContext context, String title, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: GoogleFonts.manrope(fontSize: 16, height: 1.6, color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Close',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubPage(
      title: 'Support & Legal',
      children: [
        SettingsScreen._buildActionTile(context, 'Rate the App', onTap: () {
          launchUrl(Uri.parse('https://github.com/rastyxd'));
        }),
        SettingsScreen._buildActionTile(context, 'Report a Bug', onTap: () async {
          final info = await PackageInfo.fromPlatform();
          launchUrl(Uri.parse(
              'mailto:support@rasty.uk?subject=ShiftChart%20Bug%20Report&body=Version%3A%20${info.version}%0A%0ADescribe%20the%20issue%3A'
          ));
        }),
        SettingsScreen._buildActionTile(context, 'Privacy Policy', onTap: () {
          _showContent(context, 'Privacy Policy',
              'All data is stored exclusively on your device and protected using AES encryption. ShiftChart operates entirely offline — no internet connection is required or used. Patient records and personal information never leave your device.');
        }),
        SettingsScreen._buildActionTile(context, 'Terms of Service', onTap: () {
          _showContent(context, 'Terms of Service',
              'ShiftChart is intended as a supplementary clinical tool to assist healthcare professionals with shift documentation. It is not a substitute for official medical records or institutional systems. Always verify critical information against authoritative hospital records before making clinical decisions.');
        }),
        SettingsScreen._buildActionTile(context, 'About ShiftChart', onTap: () {
          _showContent(context, 'About ShiftChart',
              'ShiftChart is a clinical shift management tool built for healthcare professionals. It provides a fully offline, secure environment for tracking patient medications, tasks, and shift records with precision and ease.\n\nAttribution:\nSound effects by YUSUF_SFX via Pixabay');        }),
        SettingsScreen._buildActionTile(
          context, 
          'View Onboarding', 
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          ),
        ),
      ],
    );
  }
}
