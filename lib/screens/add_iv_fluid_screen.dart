
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:shiftchart/models/audit_entry.dart';
import 'package:shiftchart/models/medication.dart';
import 'package:shiftchart/models/patient.dart';
import 'package:shiftchart/screens/add_medication_screen.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/services/notification_service.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:uuid/uuid.dart';

class AddIVFluidScreen extends StatefulWidget {
  final Patient patient;
  final Medication? medication;

  const AddIVFluidScreen({
    super.key,
    required this.patient,
    this.medication,
  });

  @override
  State<AddIVFluidScreen> createState() => _AddIVFluidScreenState();
}

class _AddIVFluidScreenState extends State<AddIVFluidScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _volumeController;
  late final TextEditingController _rateController;
  late final TextEditingController _additivesController;
  late TimeOfDay _selectedTime;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication?.name ?? '');
    _volumeController = TextEditingController(text: widget.medication?.diluentVolume ?? '');
    _rateController = TextEditingController(text: widget.medication?.dose ?? '');
    _additivesController = TextEditingController(text: ''); // Not stored in model yet, but added for UI
    _selectedTime = widget.medication != null
        ? TimeOfDay.fromDateTime(widget.medication!.timeDue)
        : TimeOfDay.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _volumeController.dispose();
    _rateController.dispose();
    _additivesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: use24HourFormatNotifier,
          builder: (context, use24h, _) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
              child: child!,
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _saveFluid() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a fluid name')),
      );
      return;
    }

    final now = DateTime.now();
    final due = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final medication = Medication(
      id: widget.medication?.id ?? _uuid.v4(),
      name: _nameController.text,
      dose: _rateController.text, // Using dose field for Rate (e.g., 100ml/hr)
      timeDue: due,
      type: MedType.ivFluid,
      route: 'IV',
      isDiluted: true,
      diluentVolume: _volumeController.text,
    );

    final box = Hive.box<Medication>('medications');
    if (widget.medication != null) {
      widget.medication!.name = medication.name;
      widget.medication!.dose = medication.dose;
      widget.medication!.timeDue = medication.timeDue;
      widget.medication!.route = medication.route;
      widget.medication!.isDiluted = medication.isDiluted;
      widget.medication!.diluentVolume = medication.diluentVolume;
      await widget.medication!.save();
      await NotificationService().scheduleNotification(widget.medication!, widget.patient.name);
      await AuditService.log(AuditAction.ivFluidUpdated, {
        'patient': widget.patient.name,
        'room': widget.patient.roomNumber,
        'fluid': _nameController.text,
        'rate': _rateController.text,
        'volume': _volumeController.text,
        'due': '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        'route': 'IV',
      });
    } else {
      await box.add(medication);
      widget.patient.medications ??= HiveList(box);
      widget.patient.medications!.add(medication);
      await widget.patient.save();
      await NotificationService().scheduleNotification(medication, widget.patient.name);
      await AuditService.log(AuditAction.ivFluidAdded, {
        'patient': widget.patient.name,
        'room': widget.patient.roomNumber,
        'fluid': _nameController.text,
        'rate': _rateController.text,
        'volume': _volumeController.text,
        'due': '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        'route': 'IV',
      });
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medication == null ? 'Add IV Fluid' : 'Edit IV Fluid'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Fluid Name'),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.9,
                    maxChildSize: 0.9,
                    minChildSize: 0.5,
                    builder: (context, scrollController) => Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: MedSearchWidget(
                        scrollController: scrollController,
                        theme: theme,
                        isDiluentOnly: true,
                      ),
                    ),
                  ),
                ).then((result) {
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      _nameController.text = result['generic'];
                    });
                  }
                });
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Text(
                      _nameController.text.isEmpty ? 'Select IV Fluid' : _nameController.text,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: _nameController.text.isEmpty
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.search, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Volume (ml)'),
                      _buildTextField(
                        controller: _volumeController,
                        hint: 'e.g. 1000',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Rate (ml/hr)'),
                      _buildTextField(
                        controller: _rateController,
                        hint: 'e.g. 125',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFieldLabel('Additives (Optional)'),
            _buildTextField(
              controller: _additivesController,
              hint: 'e.g. 20mEq KCl',
            ),
            const SizedBox(height: 24),
            _buildFieldLabel('Start Time'),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: use24HourFormatNotifier,
                      builder: (context, use24h, _) {
                        String timeString;
                        if (use24h) {
                          timeString = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
                        } else {
                          final hour = _selectedTime.hour == 0 ? 12 : (_selectedTime.hour > 12 ? _selectedTime.hour - 12 : _selectedTime.hour);
                          final amPm = _selectedTime.hour >= 12 ? 'PM' : 'AM';
                          timeString = '$hour:${_selectedTime.minute.toString().padLeft(2, '0')} $amPm';
                        }
                        return Text(
                          timeString,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  PrimaryButton(
                    label: widget.medication == null ? 'Start Infusion' : 'Save Changes',
                    onTap: _saveFluid,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      final testMed = Medication(
                        id: _uuid.v4(),
                        name: "Test Medication",
                        dose: "10mg",
                        timeDue: DateTime.now().add(const Duration(seconds: 5)),
                        type: MedType.medication,
                      );
                      NotificationService().scheduleNotification(testMed, widget.patient.name);
                      NotificationService().triggerClinicalVibration();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Clinical alert scheduled for 5 seconds from now', style: GoogleFonts.manrope())),
                      );
                    },
                    icon: const Icon(Icons.notification_add),
                    label: Text('Simulate Clinical Alert (5s)', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
    );
  }
}
