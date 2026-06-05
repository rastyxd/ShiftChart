import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/screens/add_medication_screen.dart';
import 'package:shiftchart/screens/patient_detail_screen.dart';
import 'package:shiftchart/theme/AppColors.dart';

class MedsOverviewScreen extends StatefulWidget {
  const MedsOverviewScreen({super.key});

  @override
  State<MedsOverviewScreen> createState() => _MedsOverviewScreenState();
}

class _MedsOverviewScreenState extends State<MedsOverviewScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute to update status colors
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPatientSelector(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Patient>('patients').listenable(),
              builder: (context, Box<Patient> patientBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<Medication>('medications').listenable(),
                  builder: (context, Box<Medication> medBox, _) {
                    final patients = patientBox.values.toList();
                    final List<Map<String, dynamic>> allMedsWithPatient = [];

                    for (var patient in patients) {
                      final meds = patient.medications?.where((m) => m.type == MedType.medication || m.type == MedType.ivFluid).toList() ?? [];
                      for (var med in meds) {
                          allMedsWithPatient.add({
                            'patient': patient,
                            'medication': med,
                          });
                      }
                    }

                    if (allMedsWithPatient.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 80,
                              color: colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No medications scheduled',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort by time due
                    allMedsWithPatient.sort((a, b) {
                      final medA = a['medication'] as Medication;
                      final medB = b['medication'] as Medication;
                      return medA.timeDue.compareTo(medB.timeDue);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: allMedsWithPatient.length,
                      itemBuilder: (context, index) {
                        final item = allMedsWithPatient[index];
                        final Medication med = item['medication'];
                        final Patient patient = item['patient'];

                        return _buildMedCard(context, med, patient);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCard(BuildContext context, Medication med, Patient patient) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color? bgColor;
    if (!med.isGiven) {
      if (med.isOverdue) {
        bgColor = colorScheme.errorContainer.withValues(alpha: 0.4);
      } else if (med.isDueSoon) {
        bgColor = Colors.yellow.withValues(alpha: 0.4);
      } else {
        bgColor = Colors.green.withValues(alpha: 0.4);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor ?? colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailScreen(patient: patient),
            ),
          );
        },
        leading: Icon(
          med.type == MedType.ivFluid ? Icons.opacity : Icons.medication,
          color: med.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                med.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: med.isGiven ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                  decoration: med.isGiven ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: use24HourFormatNotifier,
              builder: (context, use24h, _) {
                String timeString;
                if (use24h) {
                  timeString = '${med.timeDue.hour.toString().padLeft(2, '0')}:${med.timeDue.minute.toString().padLeft(2, '0')}';
                } else {
                  final hour = med.timeDue.hour == 0 ? 12 : (med.timeDue.hour > 12 ? med.timeDue.hour - 12 : med.timeDue.hour);
                  final amPm = med.timeDue.hour >= 12 ? 'PM' : 'AM';
                  timeString = '$hour:${med.timeDue.minute.toString().padLeft(2, '0')} $amPm';
                }
                return Text(
                  timeString,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: med.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${med.dose} • ${patient.name} (Room ${patient.roomNumber})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: med.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            med.isGiven ? Icons.check_circle : Icons.radio_button_unchecked,
            color: med.isGiven ? colorScheme.primary : colorScheme.outline,
            size: 32,
          ),
          onPressed: () async {
            med.isGiven = !med.isGiven;
            await med.save();
            
            if (med.isGiven) {
              await NotificationService().cancelNotification(med.id);
            } else {
              await NotificationService().scheduleNotification(med, patient.name);
            }
          },
        ),
      ),
    );
  }

  void _showPatientSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final patients = Hive.box<Patient>('patients').values.toList();
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Patient',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (patients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('No patients available')),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final p = patients[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddMedicationScreen(
                                patient: p,
                                initialType: MedType.medication,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
