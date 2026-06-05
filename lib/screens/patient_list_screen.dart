
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shiftchart/models/hpr_record.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/add_patient_screen.dart';
import 'package:shiftchart/screens/patient_detail_screen.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/theme/AppColors.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _dischargeSelected() async {
    final box = Hive.box<Patient>('patients');
    final hprBox = Hive.box<HPRRecord>('hpr_history');
    final int count = _selectedIds.length;

    try {
      for (var id in _selectedIds) {
        final patient = box.values.firstWhere((p) => p.key.toString() == id);

        // Create HPR Record
        final entries = patient.medications?.map((m) => HPREntry.fromMedication(m)).toList() ?? [];

        final record = HPRRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: patient.id,
          patientName: patient.name,
          roomNumber: patient.roomNumber,
          admissionDate: patient.admissionDate ?? DateTime.now(),
          dischargeDate: DateTime.now(),
          entries: entries,
          notes: patient.notes,
        );

        await hprBox.add(record);

        // Cancel notifications
        if (patient.medications != null) {
          for (var med in patient.medications!) {
            await NotificationService().cancelNotification(med.id);
          }
        }

        await box.delete(patient.key);
        
        AuditService.log(AuditAction.patientDeleted, {
          'id': patient.id,
          'name': patient.name,
          'reason': 'Discharge/Archive (Bulk)'
        }, outcome: true);
      }
    } catch (e) {
      AuditService.log(AuditAction.patientDeleted, {
        'reason': 'Bulk Discharge Failed',
        'error': e.toString()
      }, outcome: false);
    }
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully discharged and archived $count patient(s)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _deleteSelected() async {
    final box = Hive.box<Patient>('patients');
    final int count = _selectedIds.length;
    try {
      for (var id in _selectedIds) {
        final patient = box.values.firstWhere((p) => p.key.toString() == id);
        await box.delete(patient.key);
        
        AuditService.log(AuditAction.patientDeleted, {
          'id': patient.id,
          'name': patient.name,
          'reason': 'Direct Delete (Bulk)'
        }, outcome: true);
      }
    } catch (e) {
      AuditService.log(AuditAction.patientDeleted, {
        'reason': 'Bulk Delete Failed',
        'error': e.toString()
      }, outcome: false);
    }
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $count patient(s)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _editSelected() {
    if (_selectedIds.length != 1) return;
    final box = Hive.box<Patient>('patients');
    final patient = box.values.firstWhere((p) => p.key.toString() == _selectedIds.first);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPatientScreen(patient: patient as Patient?)),
    );
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // if patient exists dont show FAB
      floatingActionButton: Hive.box<Patient>('patients').values.isNotEmpty ?  _buildFAB(context) : null,
      body: ValueListenableBuilder<Box<Patient>>(
        valueListenable: Hive.box<Patient>('patients').listenable(),
        builder: (context, box, _) {
          final patients = box.values.toList();

          if (patients.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              final isSelected = _selectedIds.contains(patient.key.toString());
              return _buildPatientCard(context, patient, isSelected);
            },
          );
        },
      ),
    );
  }

  Widget? _buildFAB(BuildContext context) {
    if (_isSelectionMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _dischargeSelected,
            heroTag: 'discharge_patients',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Discharge'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            onPressed: _deleteSelected,
            heroTag: 'delete_patients',
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            tooltip: 'Delete without archiving',
            child: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPatientScreen()),
        );
      },
      child: const Icon(Icons.add),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 100,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(40),
          ),
          const SizedBox(height: 24),
          Text(
            'No patients yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPatientScreen()),
              );
            },
            icon: Icons.add,
            label: 'Add Patient',
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context, Patient patient, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;
    Color statusColor;
    switch (patient.status) {
      case PatientStatus.red:
        statusColor = colorScheme.error;
        break;
      case PatientStatus.yellow:
        statusColor = colorScheme.secondary;
        break;
      case PatientStatus.green:
        statusColor = colorScheme.onSurfaceVariant;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        color: isSelected ? colorScheme.primaryContainer.withAlpha(100) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onLongPress: () => _toggleSelection(patient.key.toString()),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(patient.key.toString());
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailScreen(patient: patient),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(patient.key.toString()),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Room ${patient.roomNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withAlpha(100),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
