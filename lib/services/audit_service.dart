import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/audit_entry.dart';

class AuditService {
  static const _boxName = 'audit_log';
  static const _maxEntries = 10000;

  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  static Future<void> init() async {
    await _getBox();
  }

  static Future<void> log(
      AuditAction action,
      Map<String, dynamic> data, {
        bool outcome = true,
      }) async {
    final box = await _getBox();
    
    final settings = Hive.isBoxOpen('settings') 
        ? Hive.box('settings') 
        : await Hive.openBox('settings');
    
    final entry = AuditEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      action: action,
      data: data,
      timestamp: DateTime.now(),
      nurseName: settings.get('nurseName', defaultValue: 'Unknown'),
      deviceModel: settings.get('deviceModel', defaultValue: 'Unknown'),
      deviceId: settings.get('deviceId', defaultValue: 'Unknown'),
      outcome: outcome,
    );

    final entries = await _getAll();
    entries.add(entry);

    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }

    await box.put('entries', entries.map((e) => e.toMap()).toList());
    await _exportToExternal(entry);
  }

  static Future<List<AuditEntry>> _getAll() async {
    final box = await _getBox();
    final raw = box.get('entries');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => AuditEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<AuditEntry>> getEntries({AuditAction? filter}) async {
    final all = await _getAll();
    if (filter != null) return all.where((e) => e.action == filter).toList();
    return all.reversed.toList();
  }

  static Future<List<AuditEntry>> getEntriesForPatient(String patientName) async {
    final all = await _getAll();
    return all
        .where((e) => e.data['patient']?.toString().contains(patientName) ?? false)
        .toList()
        .reversed
        .toList();
  }

  static Future<void> _exportToExternal(AuditEntry entry) async {
    try {
      if (!Platform.isAndroid) return;
      
      final dir = Directory(
        '/storage/emulated/0/Android/data/com.rasty.shiftchart/audit',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/audit.json');

      List<dynamic> existing = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        existing = jsonDecode(content);
      }

      existing.add(entry.toMap());

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(existing),
      );
    } catch (e) {
      debugPrint('Audit external export failed: $e');
    }
  }
}