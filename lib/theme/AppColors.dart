import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeName { defaultTheme, pinky, hero, batman }

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
final appThemeNotifier = ValueNotifier<AppThemeName>(AppThemeName.defaultTheme);
final accentColorNotifier = ValueNotifier<Color>(const Color(0xFF91C49B));
final eyeComfortNotifier = ValueNotifier<bool>(false);
final use24HourFormatNotifier = ValueNotifier<bool>(true); // Default to true for clinical safety
final notificationModeNotifier = ValueNotifier<NotificationMode>(NotificationMode.vibrate);
final languageNotifier = ValueNotifier<String>('English');
final reduceMotionNotifier = ValueNotifier<bool>(false);

class AppDurations {
  static bool reduceMotion = false;

  static Duration get fast => reduceMotion ? const Duration(milliseconds: 1) : const Duration(milliseconds: 150);
  static Duration get normal => reduceMotion ? const Duration(milliseconds: 1) : const Duration(milliseconds: 300);
  static Duration get slow => reduceMotion ? const Duration(milliseconds: 1) : const Duration(milliseconds: 500);
}

class AppColors {
  // Primary
  static const primary = Color(0xFF9FC8A8);
  static const onPrimary = Color(0xFF0C0E10);
  static const primaryContainer = Color(0xFF2D4B34);
  static const onPrimaryContainer = Color(0xFF91C49B);

  // Secondary
  static const secondary = Color(0xFF8FA1A6);
  static const onSecondary = Color(0xFF0C0E10);
  static const secondaryContainer = Color(0xFF1B2025);
  static const onSecondaryContainer = Color(0xFFA6ACB2);

  // Tertiary (Pending)
  static const tertiary = Color(0xFFCDF3EB);
  static const onTertiary = Color(0xFF0C0E10);
  static const tertiaryContainer = Color(0xFF1A4D5A);
  static const onTertiaryContainer = Color(0xFFCDF3EB);

  // Error (Overdue)
  static const error = Color(0xFFEE7D77);
  static const onError = Color(0xFF0C0E10);
  static const errorContainer = Color(0xFF7F2927);
  static const onErrorContainer = Color(0xFFFF9993);

  // Surface & Background
  static const surface = Color(0xFF0C0E10);
  static const onSurface = Color(0xFFE0E6ED);
  static const surfaceVariant = Color(0xFF1B2025);
  static const onSurfaceVariant = Color(0xFFA6ACB2);

  // Surface Container Tiers
  static const surfaceContainerLowest = Color(0xFF000000);
  static const surfaceContainerLow = Color(0xFF111416);
  static const surfaceContainer = Color(0xFF151A1E);
  static const surfaceContainerHigh = Color(0xFF1B2025);
  static const surfaceContainerHighest = Color(0xFF202830);
  static const surfaceBright = Color(0xFF252D33);

  // Outline
  static const outline = Color(0xFF42494E);
  static const outlineVariant = Color(0x3342494E); // 20% opacity
}

enum NotificationMode { on, vibrate, off }

class AppTheme {
  static ThemeData getTheme(AppThemeName name, ThemeMode mode, Color accentColor) {
    final isDark = mode == ThemeMode.dark;
    
    return switch (name) {
      AppThemeName.defaultTheme => _buildDefaultTheme(isDark, accentColor),
      AppThemeName.pinky => _buildPinkyTheme(isDark),
      AppThemeName.hero => _buildHeroTheme(isDark),
      AppThemeName.batman => _buildBatmanTheme(isDark),
    };
  }

  static ThemeData _buildDefaultTheme(bool isDark, Color accentColor) {
    if (!isDark) {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: accentColor,
        onPrimary: Colors.white,
        surface: const Color(0xFFF2F4F2), // Softer light green tint
        onSurface: const Color(0xFF1A1C1E),
        surfaceContainerHigh: const Color(0xFFE8ECE9),
        surfaceContainerHighest: const Color(0xFFE0E5E1),
      );
      return _buildTheme(colorScheme);
    } else {
      final colorScheme = const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ).copyWith(primary: accentColor, onPrimaryContainer: accentColor);
      return _buildTheme(colorScheme);
    }
  }

  static ThemeData _buildPinkyTheme(bool isDark) {
    final accent = const Color(0xFFFF80AB);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: accent,
      surface: isDark ? const Color(0xFF1A0F12) : const Color(0xFFFFF0F5),
      surfaceContainerHigh: isDark ? const Color(0xFF2D1B20) : const Color(0xFFFFE4EC),
      surfaceContainerHighest: isDark ? const Color(0xFF3D242B) : const Color(0xFFFFD1DE),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildHeroTheme(bool isDark) {
    final accent = const Color(0xFF2196F3); // Heroic Blue
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: accent,
      secondary: const Color(0xFFFFD700), // Gold
      surface: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F4F8),
      surfaceContainerHigh: isDark ? const Color(0xFF1B263B) : const Color(0xFFE1E8F0),
      surfaceContainerHighest: isDark ? const Color(0xFF415A77) : const Color(0xFFD1DBE8),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildBatmanTheme(bool isDark) {
    final accent = const Color(0xFFFFD600); // Bat Yellow
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: accent,
      surface: isDark ? const Color(0xFF000000) : const Color(0xFFD2D2D2),
      onSurface: isDark ? Colors.white : Colors.black,
      surfaceContainerHigh: isDark ? const Color(0xFF121212) : const Color(0xFFC5C5C5),
      surfaceContainerHighest: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFB8B8B8),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData get light => getTheme(AppThemeName.defaultTheme, ThemeMode.light, const Color(0xFF91C49B));
  static ThemeData get dark => getTheme(AppThemeName.defaultTheme, ThemeMode.dark, const Color(0xFF91C49B));

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    
    final textTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: isDark ? 0 : 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colors.transparent, thickness: 0, space: 12),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceBright : colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Usage in main.dart:
//
// import 'app_theme.dart';
//
// MaterialApp(
//   theme: AppTheme.dark,
//   ...
// )
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Status badge helper
// Usage: StatusBadge(status: MedStatus.overdue)
// ---------------------------------------------------------------------------

enum MedStatus { overdue, pending, dueSoon, given }

class StatusBadge extends StatelessWidget {
  final MedStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      MedStatus.overdue  => (AppColors.errorContainer,   AppColors.onErrorContainer,   'OVERDUE'),
      MedStatus.pending  => (AppColors.tertiaryContainer, AppColors.onTertiaryContainer, 'PENDING'),
      MedStatus.dueSoon  => (AppColors.surfaceContainerHigh, AppColors.secondary,        'DUE SOON'),
      MedStatus.given    => (AppColors.surfaceContainerLow,  AppColors.onSurfaceVariant, 'GIVEN'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 11,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gradient primary button helper (spec: primary → primaryContainer, top-left → bottom-right)
// Usage: GradientButton(label: 'Save', onTap: () {})
// ---------------------------------------------------------------------------

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  final IconData? icon;
  
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? MediaQuery.of(context).size.width - 48,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ),
          child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status dot helper (for patient list cards)
// Usage: StatusDot(status: MedStatus.overdue)
// ---------------------------------------------------------------------------

class StatusDot extends StatelessWidget {
  final MedStatus status;
  const StatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MedStatus.overdue => AppColors.error,
      MedStatus.dueSoon => AppColors.secondary,
      MedStatus.pending => AppColors.tertiary,
      MedStatus.given   => AppColors.onSurfaceVariant,
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
