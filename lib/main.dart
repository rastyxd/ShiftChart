import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shiftchart/models/hpr_record.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/auth_gate_screen.dart';
import 'package:shiftchart/screens/onboarding_screen.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/foreground_service.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/services/in_app_notification_service.dart';
import 'package:shiftchart/theme/AppColors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive first
  await Hive.initFlutter();

  // Initialize Local Notifications Service (works offline)
  await NotificationService().init();
  
  // Initialize Audit Log
  await AuditService.init();
  
  // Initialize Foreground Service
  ForegroundService().init();
  ForegroundService().startService();

  final secureStorage = const FlutterSecureStorage();
  var containsEncryptionKey = await secureStorage.containsKey(
    key: 'encryptionKey',
  );
  if (!containsEncryptionKey) {
    var key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'encryptionKey',
      value: base64UrlEncode(key),
    );
  }

  var encryptionKey = base64Url.decode(
    await secureStorage.read(key: 'encryptionKey') as String,
  );

  // Register Adapters
  Hive.registerAdapter(MedicationAdapter());
  Hive.registerAdapter(PatientAdapter());
  Hive.registerAdapter(PatientStatusAdapter());
  Hive.registerAdapter(MedTypeAdapter());
  Hive.registerAdapter(HPRRecordAdapter());
  Hive.registerAdapter(HPREntryAdapter());

  // Open Boxes
  await Hive.openBox<Patient>(
    'patients',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
  await Hive.openBox<Medication>(
    'medications',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
  await Hive.openBox<HPRRecord>(
    'hpr_history',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  final medCatalogBox = await Hive.openBox('med_catalog');
  if (medCatalogBox.isEmpty) {
    try {
      final String response = await rootBundle.loadString('lib/assets/medlist.json');
      final List<dynamic> data = json.decode(response);
      for (var item in data) {
        // Use generic name as key for easy lookup and to prevent duplicates
        medCatalogBox.put(item['generic'], item);
      }
    } catch (e) {
      debugPrint('Error migrating medList to Hive: $e');
    }
  }

  final taskCatalogBox = await Hive.openBox('task_catalog');
  if (taskCatalogBox.isEmpty) {
    try {
      final String response = await rootBundle.loadString('lib/assets/nurse_tasks.json');
      final List<dynamic> data = json.decode(response);
      for (var item in data) {
        taskCatalogBox.put(item['name'], item);
      }
    } catch (e) {
      debugPrint('Error migrating nurse_tasks to Hive: $e');
    }
  }

  final diluentsCatalogBox = await Hive.openBox('diluents_catalog');
  if (diluentsCatalogBox.isEmpty) {
    try {
      final String response = await rootBundle.loadString('lib/assets/diluents.json');
      final List<dynamic> data = json.decode(response);
      for (var item in data) {
        if (item.containsKey('generic')) {
          diluentsCatalogBox.put(item['generic'], item);
        } else if (item.containsKey('others')) {
          for (var other in item['others']) {
            diluentsCatalogBox.put(other['generic'], other);
          }
        }
      }
    } catch (e) {
      debugPrint('Error migrating diluents to Hive: $e');
    }
  }

  final settingsBox = await Hive.openBox('settings');

  // Load device info if not already stored
  if (!settingsBox.containsKey('deviceId')) {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      await settingsBox.put('deviceModel', androidInfo.model);
      await settingsBox.put('deviceId', androidInfo.id);
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      await settingsBox.put('deviceModel', iosInfo.utsname.machine);
      await settingsBox.put('deviceId', iosInfo.identifierForVendor);
    }
  }

  // Load saved preferences
  final savedTheme = settingsBox.get('themeMode', defaultValue: 'dark');
  themeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
  reduceMotionNotifier.addListener(() {
    AppDurations.reduceMotion = reduceMotionNotifier.value;
  });
  eyeComfortNotifier.value = settingsBox.get('eyeComfort', defaultValue: false);
  reduceMotionNotifier.value = settingsBox.get('reduceMotion', defaultValue: false);
  AppDurations.reduceMotion = reduceMotionNotifier.value;


  final savedMode = settingsBox.get('notificationMode', defaultValue: 'on');
  notificationModeNotifier.value = NotificationMode.values.firstWhere(
    (e) => e.name == savedMode,
    orElse: () => NotificationMode.on,
  );

  final savedThemeName = settingsBox.get('appThemeName');
  if (savedThemeName != null) {
    appThemeNotifier.value = AppThemeName.values.firstWhere(
      (e) => e.name == savedThemeName,
      orElse: () => AppThemeName.defaultTheme,
    );
  }
  final savedAccentColor = settingsBox.get('accentColor');
  if (savedAccentColor != null) {
    accentColorNotifier.value = Color(savedAccentColor);
  }

  languageNotifier.value = settingsBox.get('language', defaultValue: 'English');
  use24HourFormatNotifier.value = settingsBox.get('use24HourFormat', defaultValue: true);

  runApp(const ShiftChartApp());
}

class ShiftChartApp extends StatelessWidget {
  const ShiftChartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder2<ThemeMode, bool>(
      first: themeNotifier,
      second: eyeComfortNotifier,
      builder: (context, currentMode, isEyeComfort, child) {
        return ValueListenableBuilder2<AppThemeName, Color>(
          first: appThemeNotifier,
          second: accentColorNotifier,
          builder: (context, themeName, accentColor, _) {
            return ColorFiltered(
              colorFilter: ColorFilter.mode(
                isEyeComfort ? Colors.orange.withValues(alpha: 0.12) : Colors.transparent,
                BlendMode.darken,
              ),
              child: MaterialApp(
                title: 'ShiftChart',
                debugShowCheckedModeBanner: false,
                navigatorKey: InAppNotificationService().navigatorKey,
                theme: AppTheme.getTheme(themeName, ThemeMode.light, accentColor),
                darkTheme: AppTheme.getTheme(themeName, ThemeMode.dark, accentColor),
                themeMode: currentMode,
                home: Hive.box('settings').get('hasSeenOnboarding', defaultValue: false)
                    ? const AuthGateScreen()
                    : const OnboardingScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

// Helper for listening to two ValueNotifiers
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;
  final Widget? child;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
    valueListenable: first,
    builder: (context, a, _) => ValueListenableBuilder<B>(
      valueListenable: second,
      builder: (context, b, _) => builder(context, a, b, child),
    ),
  );
}
