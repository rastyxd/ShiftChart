import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/screens/add_task_screen.dart';
import 'package:shiftchart/theme/AppColors.dart';

class TasksOverviewScreen extends StatefulWidget {
  const TasksOverviewScreen({super.key});

  @override
  State<TasksOverviewScreen> createState() => _TasksOverviewScreenState();
}

class _TasksOverviewScreenState extends State<TasksOverviewScreen> {
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
                    final List<Map<String, dynamic>> allTasksWithPatient = [];

                    for (var patient in patients) {
                      final tasks = patient.medications?.where((m) => m.type == MedType.vitalCheck).toList() ?? [];
                      for (var task in tasks) {
                          allTasksWithPatient.add({
                            'patient': patient,
                            'task': task,
                          });
                      }
                    }

                    if (allTasksWithPatient.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 80,
                              color: colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks scheduled',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Sort by time due
                    allTasksWithPatient.sort((a, b) {
                      final taskA = a['task'] as Medication;
                      final taskB = b['task'] as Medication;
                      return taskA.timeDue.compareTo(taskB.timeDue);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: allTasksWithPatient.length,
                      itemBuilder: (context, index) {
                        final item = allTasksWithPatient[index];
                        final Medication task = item['task'];
                        final Patient patient = item['patient'];

                        return _buildTaskCard(context, task, patient);
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

  Widget _buildTaskCard(BuildContext context, Medication task, Patient patient) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color? bgColor;
    if (!task.isGiven) {
      if (task.isOverdue) {
        bgColor = colorScheme.errorContainer.withValues(alpha: 0.4);
      } else if (task.isDueSoon) {
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
              builder: (context) => AddTaskScreen(
                patient: patient,
                task: task,
              ),
            ),
          );
        },
        leading: Icon(
          Icons.monitor_heart,
          color: task.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: task.isGiven ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                  decoration: task.isGiven ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: use24HourFormatNotifier,
              builder: (context, use24h, _) {
                String timeString;
                if (use24h) {
                  timeString = '${task.timeDue.hour.toString().padLeft(2, '0')}:${task.timeDue.minute.toString().padLeft(2, '0')}';
                } else {
                  final hour = task.timeDue.hour == 0 ? 12 : (task.timeDue.hour > 12 ? task.timeDue.hour - 12 : task.timeDue.hour);
                  final amPm = task.timeDue.hour >= 12 ? 'PM' : 'AM';
                  timeString = '$hour:${task.timeDue.minute.toString().padLeft(2, '0')} $amPm';
                }
                return Text(
                  timeString,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: task.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurface,
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
              '${patient.name} (Room ${patient.roomNumber})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: task.isGiven ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            task.isGiven ? Icons.check_circle : Icons.radio_button_unchecked,
            color: task.isGiven ? colorScheme.primary : colorScheme.outline,
            size: 32,
          ),
          onPressed: () async {
            task.isGiven = !task.isGiven;
            await task.save();

            if (task.isGiven) {
              await NotificationService().cancelNotification(task.id);
            } else {
              await NotificationService().scheduleNotification(task, patient.name);
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
                              builder: (context) => AddTaskScreen(
                                patient: p,
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
