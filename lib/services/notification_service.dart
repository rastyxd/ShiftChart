import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    // Create a high importance channel for clinical alerts
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'clinical_alerts_v3', // Incremented to v3 for Calmness default
      'Clinical Alerts',
      description: 'Critical patient care notifications',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('calmness'),
      enableVibration: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);

    // Request notification permission (required for Android 13+)
    await androidPlugin?.requestNotificationsPermission();

    // Request exact alarm permission (required for Android 12+)
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> scheduleNotification(Medication med, String patientName) async {
    if (med.isGiven) {
      await cancelNotification(med.id);
      return;
    }

    final mode = notificationModeNotifier.value;
    if (mode == NotificationMode.off) return;

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(med.timeDue, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final bool isVibrateOnly = mode == NotificationMode.vibrate;
    // Clinical pattern: [wait, on, off, on, off, on]
    final List<int> vibrationPattern = [0, 500, 200, 500, 200, 1000];

    await _notificationsPlugin.zonedSchedule(
      id: med.id.hashCode,
      title: 'Medication Due: ${med.name}',
      body: 'Patient: $patientName - Dose: ${med.dose}',
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'clinical_alerts_v3',
          'Clinical Alerts',
          channelDescription: 'Critical patient care notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: !isVibrateOnly,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(vibrationPattern),
          fullScreenIntent: true,
          sound: isVibrateOnly ? null : const RawResourceAndroidNotificationSound('calmness'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(String medId) async {
    await _notificationsPlugin.cancel(id: medId.hashCode);
  }

  void triggerClinicalVibration() async {
    if (await Vibration.hasVibrator()) {
      // Long vibration for clinical alert
      Vibration.vibrate(pattern: [0, 1000]);
    }
  }
}
