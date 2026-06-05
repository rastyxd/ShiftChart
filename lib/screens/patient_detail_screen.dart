

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:printing/printing.dart';
import 'package:shiftchart/models/hpr_record.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/add_patient_screen.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/screens/add_medication_screen.dart';
import 'package:shiftchart/screens/add_iv_fluid_screen.dart';
import 'package:shiftchart/screens/add_task_screen.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:shiftchart/services/pdf_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _item1Animation;
  late Animation<double> _item2Animation;
  late Animation<double> _item3Animation;
  bool _isMenuOpen = false;
  final Set<String> _selectedMedIds = {};
  bool _isSelectionMode = false;
  Timer? _timer;


  void _toggleMedSelection(String id) {
    setState(() {
      if (_selectedMedIds.contains(id)) {
        _selectedMedIds.remove(id);
        if (_selectedMedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMedIds.add(id);
        _isSelectionMode = true;
        if (_isMenuOpen) _toggleMenu();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedMedIds.clear();
      _isSelectionMode = false;
    });
  }

  void _deleteSelectedMeds() async {
    final medBox = Hive.box<Medication>('medications');
    for (var id in _selectedMedIds) {
      final med = medBox.values.firstWhere((m) => m.id == id);
      
      AuditService.log(AuditAction.medicationDeleted, {
        'patient': widget.patient.name,
        'medication': med.name,
      });

      // Cancel notification before deleting
      await NotificationService().cancelNotification(med.id);
      widget.patient.medications?.remove(med);
      await med.delete();
    }
    await widget.patient.save();
    _exitSelectionMode();
  }

  void _editSelectedMed() {
    if (_selectedMedIds.length != 1) return;
    final medBox = Hive.box<Medication>('medications');
    final med = medBox.values.firstWhere((m) => m.id == _selectedMedIds.first);
    if (med.type == MedType.vitalCheck) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTaskScreen(
            patient: widget.patient,
            task: med,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddMedicationScreen(
            patient: widget.patient,
            medication: med,
          ),
        ),
      );
    }
    _exitSelectionMode();
  }

  @override
  void initState() {
    super.initState();
    AuditService.log(AuditAction.patientAccessed, {
      'id': widget.patient.id,
      'name': widget.patient.name,
    });
    _controller = AnimationController(
      duration: AppDurations.normal,
      vsync: this,
    );
    _item1Animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _item2Animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );
    _item3Animation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _navigateToAdd(MedType type, {bool isDiluent = false}) {
    _toggleMenu();
    if (type == MedType.vitalCheck) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTaskScreen(
            patient: widget.patient,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddMedicationScreen(
            patient: widget.patient,
            initialType: type,
            isDiluentMode: isDiluent,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close : Icons.arrow_back),
          onPressed: () => _isSelectionMode ? _exitSelectionMode() : Navigator.pop(context),
        ),
        title: _isSelectionMode
            ? Text('${_selectedMedIds.length} Selected')
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPatientScreen(patient: widget.patient),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.patient.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                    Text(
                      'Room ${widget.patient.roomNumber}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
        actions: [
          if (_isSelectionMode) ...[
            if (_selectedMedIds.length == 1)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editSelectedMed,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelectedMeds,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saving History PDF...')),
                );
                try {
                  final path = await PdfService.savePatientHistory(widget.patient);
                  
                  AuditService.log(AuditAction.patientExported, {
                    'id': widget.patient.id,
                    'name': widget.patient.name,
                    'format': 'PDF_HISTORY'
                  }, outcome: true);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('History saved to Documents'),
                        action: SnackBarAction(
                          label: 'Open',
                          onPressed: () => Printing.layoutPdf(
                            onLayout: (_) => File(path).readAsBytesSync(),
                          ),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  AuditService.log(AuditAction.patientExported, {
                    'id': widget.patient.id,
                    'name': widget.patient.name,
                    'error': e.toString()
                  }, outcome: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving PDF: $e')),
                    );
                  }
                }
              },
            ),
            IconButton(
              style: IconButton.styleFrom(
                padding: const EdgeInsets.fromLTRB(0, 0, 25, 0),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              icon: const Icon(Icons.exit_to_app_outlined),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    title: Text(
                      'Discharge patient?',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'Patient "${widget.patient.name}" will be discharged from Room ${widget.patient.roomNumber}. This action cannot be undone.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: PrimaryButton(
                          label: 'Discharge',
                          onTap: () async {
                            final patientKey = widget.patient.key;
                            final patient = widget.patient;
                            
                            // Archive to HPR first
                            final hprBox = Hive.box<HPRRecord>('hpr_history');
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

                            // Cancel all notifications for this patient's medications
                            if (patient.medications != null) {
                              for (var med in patient.medications!) {
                                await NotificationService().cancelNotification(med.id);
                              }
                            }
                            
                            await Hive.box<Patient>('patients').delete(patientKey);
                            
                            AuditService.log(AuditAction.patientDeleted, {
                              'id': patient.id,
                              'name': patient.name,
                              'reason': 'Discharge/Archive'
                            });

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context); // Go back to main screen
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Patient ${patient.name} discharged and archived', style: GoogleFonts.manrope()),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<Box<Patient>>(
            valueListenable: Hive.box<Patient>('patients').listenable(),
            builder: (context, box, _) {
              final patient = box.get(widget.patient.key) ?? widget.patient;
              final meds = patient.medications?.toList() ?? [];
              
              if (meds.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No medications scheduled',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }

              final scheduledMeds = meds.where((m) => !m.isPrn).toList();
              final prnMeds = meds.where((m) => m.isPrn).toList();

              scheduledMeds.sort((a, b) => a.timeDue.compareTo(b.timeDue));
              prnMeds.sort((a, b) => a.name.compareTo(b.name));

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (scheduledMeds.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Scheduled'),
                    const SizedBox(height: 12),
                    ...scheduledMeds.map((m) => _buildMedRow(context, m, _selectedMedIds.contains(m.id))),
                    const SizedBox(height: 24),
                  ],
                  if (prnMeds.isNotEmpty) ...[
                    _buildSectionHeader(context, 'PRN / As Needed'),
                    const SizedBox(height: 12),
                    ...prnMeds.map((m) => _buildMedRow(context, m, _selectedMedIds.contains(m.id))),
                  ],
                ],
              );
            },
          ),
          IgnorePointer(
            ignoring: !_isMenuOpen,
            child: FadeTransition(
              opacity: _controller,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAnimatedMenuItem(
            label: 'Vital/Pulse Check',
            icon: Icons.monitor_heart_outlined,
            onTap: () => _navigateToAdd(MedType.vitalCheck),
            animation: _item1Animation,
          ),
          const SizedBox(height: 16),
          _buildAnimatedMenuItem(
            label: 'Add Medication',
            icon: Icons.medication_outlined,
            onTap: () => _navigateToAdd(MedType.medication),
            animation: _item2Animation,
          ),
          const SizedBox(height: 16),
          _buildAnimatedMenuItem(
            label: 'IV Fluid (Infusion)',
            icon: Icons.opacity,
            onTap: () {
              _toggleMenu();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddIVFluidScreen(patient: widget.patient),
                ),
              );
            },
            animation: _item3Animation,
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _toggleMenu,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _controller,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
    );
  }

  Widget _buildAnimatedMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Animation<double> animation,
  }) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        alignment: Alignment.bottomRight,
        child: _buildMenuItem(label: label, icon: icon, onTap: onTap),
      ),
    );
  }

  Widget _buildMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 16),
        FloatingActionButton.small(
          onPressed: onTap,
          heroTag: label,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
      ],
    );
  }

  Widget _buildMedRow(BuildContext context, Medication med, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color? bgColor;
    if (isSelected) {
      bgColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
    } else if (!med.isGiven) {
      if (med.isOverdue) {
        bgColor = colorScheme.errorContainer.withValues(alpha: 0.12);
      } else if (med.isDueSoon) {
        bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.12);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor ?? colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<Box<Medication>>(
        valueListenable: Hive.box<Medication>('medications').listenable(),
        builder: (context, box, _) {
          final m = box.get(med.key) ?? med;
          final isVital = m.type == MedType.vitalCheck;
          final isIV = m.type == MedType.ivFluid;

          return ListTile(
            onLongPress: () => _toggleMedSelection(m.id),
            onTap: () {
              if (_isSelectionMode) {
                _toggleMedSelection(m.id);
              } else {
                // Regular tap action if needed, currently does nothing or could show details
              }
            },
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleMedSelection(m.id),
                  )
                : Icon(
                    isVital
                        ? Icons.monitor_heart
                        : isIV
                            ? Icons.opacity
                            : Icons.medication,
                    color:
                        m.isGiven
                            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                            : colorScheme.primary,
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              m.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: m.isGiven ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                decoration: m.isGiven ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              m.dose,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: m.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!m.isPrn)
                  ValueListenableBuilder<bool>(
                    valueListenable: use24HourFormatNotifier,
                    builder: (context, use24h, _) {
                      String timeString;
                      if (use24h) {
                        timeString = '${m.timeDue.hour.toString().padLeft(2, '0')}:${m.timeDue.minute.toString().padLeft(2, '0')}';
                      } else {
                        final hour = m.timeDue.hour == 0 ? 12 : (m.timeDue.hour > 12 ? m.timeDue.hour - 12 : m.timeDue.hour);
                        final amPm = m.timeDue.hour >= 12 ? 'PM' : 'AM';
                        timeString = '$hour:${m.timeDue.minute.toString().padLeft(2, '0')} $amPm';
                      }
                      return Text(
                        timeString,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: m.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 16),
                if (!_isSelectionMode)
                  IconButton(
                    icon: Icon(
                      m.isGiven ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: m.isGiven ? colorScheme.primary : colorScheme.outline,
                      size: 32,
                    ),
                    onPressed: () async {
                      try {
                        m.isGiven = !m.isGiven;
                        await m.save();

                        AuditService.log(
                          m.isGiven ? AuditAction.medicationGiven : AuditAction.medicationReset,
                          {
                            'patient': widget.patient.name,
                            'medication': m.name,
                            'dose': m.dose,
                          },
                          outcome: true,
                        );

                        if (m.isGiven) {
                          await NotificationService().cancelNotification(m.id);
                        } else {
                          if (!m.isPrn) {
                            await NotificationService().scheduleNotification(m, widget.patient.name);
                          }
                        }
                      } catch (e) {
                        AuditService.log(
                          m.isGiven ? AuditAction.medicationReset : AuditAction.medicationGiven,
                          {
                            'patient': widget.patient.name,
                            'medication': m.name,
                            'error': e.toString(),
                          },
                          outcome: false,
                        );
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

