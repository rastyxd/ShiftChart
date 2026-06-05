import 'package:flutter/material.dart';

enum AuditAction {
  // Patient
  patientCreated, patientUpdated, patientDeleted, patientAccessed, patientExported,
  // Medication
  medicationAdded, medicationUpdated, medicationDeleted, medicationGiven, medicationReset,
  // Task
  taskAdded, taskUpdated, taskDeleted, taskCompleted, taskReopened,
  // IV Fluid
  ivFluidAdded, ivFluidUpdated, ivFluidDeleted,
  // HPR
  hprGenerated, hprSaved,
  // Data
  allDataCleared, dataExported,
  // App
  appUnlocked, settingsChanged,
}

class AuditEntry {
  final String id;
  final AuditAction action;
  final Map<String, dynamic> data; // structured fields
  final DateTime timestamp;
  final String nurseName;
  final String deviceModel;
  final String deviceId;
  final bool outcome; // true = success, false = failure

  AuditEntry({
    required this.id,
    required this.action,
    required this.data,
    required this.timestamp,
    required this.nurseName,
    required this.deviceModel,
    required this.deviceId,
    this.outcome = true,
  });

  String get actionLabel => switch (action) {
    AuditAction.patientCreated    => 'Patient Created',
    AuditAction.patientUpdated    => 'Patient Updated',
    AuditAction.patientDeleted    => 'Patient Deleted',
    AuditAction.patientAccessed   => 'Patient Accessed',
    AuditAction.patientExported   => 'Patient Exported',
    AuditAction.medicationAdded   => 'Medication Added',
    AuditAction.medicationUpdated => 'Medication Updated',
    AuditAction.medicationDeleted => 'Medication Deleted',
    AuditAction.medicationGiven   => 'Medication Given',
    AuditAction.medicationReset   => 'Medication Reset',
    AuditAction.taskAdded         => 'Task Added',
    AuditAction.taskUpdated       => 'Task Updated',
    AuditAction.taskDeleted       => 'Task Deleted',
    AuditAction.taskCompleted     => 'Task Completed',
    AuditAction.taskReopened      => 'Task Reopened',
    AuditAction.ivFluidAdded      => 'IV Fluid Added',
    AuditAction.ivFluidUpdated    => 'IV Fluid Updated',
    AuditAction.ivFluidDeleted    => 'IV Fluid Deleted',
    AuditAction.hprGenerated      => 'HPR Generated',
    AuditAction.hprSaved          => 'HPR Saved',
    AuditAction.allDataCleared    => 'All Data Cleared',
    AuditAction.dataExported      => 'Data Exported',
    AuditAction.appUnlocked       => 'App Unlocked',
    AuditAction.settingsChanged   => 'Settings Changed',
  };

  // Category color for the UI badge
  AuditCategory get category => switch (action) {
    AuditAction.patientCreated ||
    AuditAction.patientUpdated ||
    AuditAction.patientDeleted ||
    AuditAction.patientAccessed ||
    AuditAction.patientExported   => AuditCategory.patient,
    AuditAction.medicationAdded  ||
    AuditAction.medicationUpdated ||
    AuditAction.medicationDeleted ||
    AuditAction.medicationGiven  ||
    AuditAction.medicationReset   => AuditCategory.medication,
    AuditAction.taskAdded        ||
    AuditAction.taskUpdated      ||
    AuditAction.taskDeleted      ||
    AuditAction.taskCompleted    ||
    AuditAction.taskReopened      => AuditCategory.task,
    AuditAction.ivFluidAdded     ||
    AuditAction.ivFluidUpdated   ||
    AuditAction.ivFluidDeleted    => AuditCategory.ivFluid,
    AuditAction.hprGenerated     ||
    AuditAction.hprSaved          => AuditCategory.hpr,
    AuditAction.allDataCleared   ||
    AuditAction.dataExported      => AuditCategory.data,
    AuditAction.appUnlocked      ||
    AuditAction.settingsChanged   => AuditCategory.app,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'action': action.index,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'nurseName': nurseName,
    'deviceModel': deviceModel,
    'deviceId': deviceId,
    'outcome': outcome,
  };

  factory AuditEntry.fromMap(Map<String, dynamic> m) => AuditEntry(
    id: m['id'],
    action: AuditAction.values[m['action']],
    data: Map<String, dynamic>.from(m['data'] ?? {}),
    timestamp: DateTime.parse(m['timestamp']),
    nurseName: m['nurseName'] ?? 'Unknown',
    deviceModel: m['deviceModel'] ?? 'Unknown',
    deviceId: m['deviceId'] ?? 'Unknown',
    outcome: m['outcome'] ?? true,
  );
}

extension AuditCategoryExtension on AuditCategory {
  String get label => switch (this) {
    AuditCategory.patient    => 'Patient',
    AuditCategory.medication => 'Medication',
    AuditCategory.task       => 'Task',
    AuditCategory.ivFluid    => 'IV Fluid',
    AuditCategory.hpr        => 'HPR',
    AuditCategory.data       => 'Data',
    AuditCategory.app        => 'App',
  };

  Color color(ColorScheme scheme) => switch (this) {
    AuditCategory.patient    => scheme.primary,
    AuditCategory.medication => Colors.green,
    AuditCategory.task       => Colors.orange,
    AuditCategory.ivFluid    => Colors.blue,
    AuditCategory.hpr        => Colors.purple,
    AuditCategory.data       => scheme.error,
    AuditCategory.app        => Colors.grey,
  };
}

enum AuditCategory { patient, medication, task, ivFluid, hpr, data, app }