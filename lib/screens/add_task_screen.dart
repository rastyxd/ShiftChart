
import 'package:flutter/material.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/add_medication_screen.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class AddTaskScreen extends StatefulWidget {
  final Patient patient;
  final Medication? task;

  const AddTaskScreen({
    super.key,
    required this.patient,
    this.task,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _repeatController;
  late DateTime _selectedDateTime;
  bool _isRepeat = false;
  bool _isMinutes = false;
  bool _saveForFuture = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _repeatController = TextEditingController(
      text: widget.task?.repeatValue?.toString() ?? '',
    );
    _isRepeat = widget.task?.repeatValue != null;
    _isMinutes = widget.task?.isRepeatInMinutes ?? false;
    _selectedDateTime = widget.task?.timeDue ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Future<void> _showTaskSearch() async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => MedSearchWidget(
            scrollController: scrollController,
            theme: theme,
            isTaskOnly: true,
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _nameController.text = result['name'] ?? result['generic'] ?? '';
      });
    }
  }

  void _saveTask() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_saveForFuture) {
      final taskCatalogBox = Hive.box('task_catalog');
      if (!taskCatalogBox.containsKey(name)) {
        await taskCatalogBox.put(name, {
          'name': name,
          'category': 'Custom',
        });
      }
    }

    final timeDue = _selectedDateTime;

    if (widget.task != null) {
      widget.task!.name = name;
      widget.task!.timeDue = timeDue;
      widget.task!.repeatValue = _isRepeat ? int.tryParse(_repeatController.text) : null;
      widget.task!.isRepeatInMinutes = _isMinutes;
      await widget.task!.save();
      await NotificationService().scheduleNotification(widget.task!, widget.patient.name);
      await AuditService.log(AuditAction.taskUpdated, {
        'patient': widget.patient.name,
        'room': widget.patient.roomNumber,
        'task': name,
        'due': '${timeDue.hour.toString().padLeft(2, '0')}:${timeDue.minute.toString().padLeft(2, '0')}',
        'repeat': _isRepeat ? '${_repeatController.text} ${_isMinutes ? 'minutes' : 'hours'}' : 'No',
      });
    } else {
      final newTask = Medication(
        id: _uuid.v4(),
        name: name,
        dose: 'Scheduled Check',
        timeDue: timeDue,
        type: MedType.vitalCheck,
        repeatValue: _isRepeat ? int.tryParse(_repeatController.text) : null,
        isRepeatInMinutes: _isMinutes,
      );
      
      final medBox = Hive.box<Medication>('medications');
      await medBox.add(newTask);
      await AuditService.log(AuditAction.medicationAdded, {
        'patient': widget.patient.name,
        'room': widget.patient.roomNumber,
        'medication': name,
        'dose': 'Scheduled Check',
        'type': 'Vital Check',
        'due': '${timeDue.hour.toString().padLeft(2, '0')}:${timeDue.minute.toString().padLeft(2, '0')}',
        'repeat': _isRepeat ? '${_repeatController.text} ${_isMinutes ? 'minutes' : 'hours'}' : 'No',
      });
      
      if (widget.patient.medications == null) {
        widget.patient.medications = HiveList(medBox);
      }
      widget.patient.medications!.add(newTask);
      await widget.patient.save();
      await AuditService.log(AuditAction.medicationAdded, {
        'patient': widget.patient.name,
        'room': widget.patient.roomNumber,
        'medication': name,
        'dose': 'Scheduled Check',
        'type': 'Vital Check',
        'due': '${timeDue.hour.toString().padLeft(2, '0')}:${timeDue.minute.toString().padLeft(2, '0')}',
        'repeat': _isRepeat ? '${_repeatController.text} ${_isMinutes ? 'minutes' : 'hours'}' : 'No',
      });
      // Schedule notification
      await NotificationService().scheduleNotification(newTask, widget.patient.name);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? 'Edit Task' : 'Add Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildFieldLabel('Check Name'),
          TextField(
            onTap: _showTaskSearch,
            controller: _nameController,
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              suffixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(30)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_nameController.text.isNotEmpty &&
              !Hive.box('task_catalog').containsKey(_nameController.text))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: InkWell(
                onTap: () => setState(() => _saveForFuture = !_saveForFuture),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _saveForFuture,
                        activeColor: colorScheme.primary,
                        onChanged: (val) => setState(() => _saveForFuture = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Save for future reference',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          _buildFieldLabel('Time Due'),
          InkWell(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                builder: (context, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: use24HourFormatNotifier,
                    builder: (context, use24h, _) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
                        child: child!,
                      );
                    }
                  );
                },
              );
              if (time != null) {
                final now = DateTime.now();
                DateTime scheduled = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  time.hour,
                  time.minute,
                );

                if (scheduled.isBefore(now)) {
                  scheduled = scheduled.add(const Duration(days: 1));
                }

                setState(() {
                  _selectedDateTime = scheduled;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: use24HourFormatNotifier,
                        builder: (context, use24h, _) {
                          String timeString;
                          if (use24h) {
                            timeString = '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}';
                          } else {
                            final hour = _selectedDateTime.hour == 0 ? 12 : (_selectedDateTime.hour > 12 ? _selectedDateTime.hour - 12 : _selectedDateTime.hour);
                            final amPm = _selectedDateTime.hour >= 12 ? 'PM' : 'AM';
                            timeString = '$hour:${_selectedDateTime.minute.toString().padLeft(2, '0')} $amPm';
                          }
                          return Text(
                            timeString,
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          );
                        }
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _selectedDateTime.day == DateTime.now().day ? 'Today' : 'Tomorrow',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: use24HourFormatNotifier,
                      builder: (context, use24h, _) {
                        final now = DateTime.now();
                        final diff = _selectedDateTime.difference(now);
                        String timeText = '';
                        
                        if (diff.isNegative) {
                          timeText = 'Just now';
                        } else {
                          final hours = diff.inHours;
                          final minutes = diff.inMinutes % 60;
                          
                          if (hours > 0) {
                            timeText = 'due in $hours ${hours == 1 ? 'hour' : 'hours'}${minutes > 0 ? ' and $minutes ${minutes == 1 ? 'minute' : 'minutes'}' : ''}';
                          } else {
                            timeText = 'due in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
                          }
                        }

                        String formattedTime;
                        if (use24h) {
                          formattedTime = '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}';
                        } else {
                          final hour = _selectedDateTime.hour == 0 ? 12 : (_selectedDateTime.hour > 12 ? _selectedDateTime.hour - 12 : _selectedDateTime.hour);
                          final amPm = _selectedDateTime.hour >= 12 ? 'PM' : 'AM';
                          formattedTime = '$hour:${_selectedDateTime.minute.toString().padLeft(2, '0')} $amPm';
                        }

                        return Text(
                          'Safe-Check: $formattedTime • $timeText',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Repeat Task', style: textTheme.labelLarge),
              const Spacer(),
              Switch(
                value: _isRepeat,
                onChanged: (val) => setState(() => _isRepeat = val),
              ),
            ],
          ),
          if (_isRepeat) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repeatController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Every...',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _buildRepeatUnit('Hrs', false),
                      _buildRepeatUnit('Mins', true),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
          Center(
            child: PrimaryButton(
              onTap: _saveTask,
              label: widget.task != null ? 'Update Task' : 'Save Task',
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildRepeatUnit(String label, bool isMins) {
    final isSelected = _isMinutes == isMins;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _isMinutes = isMins),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
