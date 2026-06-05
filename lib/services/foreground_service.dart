import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._internal();
  factory ForegroundService() => _instance;
  ForegroundService._internal();

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shiftchart_foreground',
        channelName: 'Shift Management',
        channelDescription: 'Keeps clinical alerts active during your shift',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<ServiceRequestResult> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'ShiftChart Active',
        notificationText: 'Monitoring clinical alerts...',
        callback: startCallback,
      );
    }
  }

  Future<ServiceRequestResult> stopService() async {
    return FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ShiftHandler());
}

class ShiftHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize Hive in the background isolate
    await Hive.initFlutter();
    
    const secureStorage = FlutterSecureStorage();
    final encryptionKeyStr = await secureStorage.read(key: 'encryptionKey');
    if (encryptionKeyStr != null) {
      final encryptionKey = base64Url.decode(encryptionKeyStr);
      
      // Register Adapters
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicationAdapter());
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PatientAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PatientStatusAdapter());
      if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(MedTypeAdapter());

      // Open Boxes
      await Hive.openBox<Patient>(
        'patients',
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateStats();
  }

  Future<void> _updateStats() async {
    if (!Hive.isBoxOpen('patients')) return;
    
    final box = Hive.box<Patient>('patients');
    int dueSoonCount = 0;
    int overdueCount = 0;

    for (var patient in box.values) {
      if (patient.medications != null) {
        for (var med in patient.medications!) {
          if (!med.isGiven) {
            if (med.isOverdue) {
              overdueCount++;
            } else if (med.isDueSoon) {
              dueSoonCount++;
            }
          }
        }
      }
    }

    String statusText = 'Monitoring clinical alerts...';
    if (overdueCount > 0 || dueSoonCount > 0) {
      List<String> alerts = [];
      if (overdueCount > 0) alerts.add('$overdueCount OVERDUE');
      if (dueSoonCount > 0) alerts.add('$dueSoonCount due soon');
      statusText = alerts.join(' • ');
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'Shift Overview',
      notificationText: statusText,
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isShutdown) async {
    if (Hive.isBoxOpen('patients')) {
      await Hive.close();
    }
  }
}
