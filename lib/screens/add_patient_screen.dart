import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shiftchart/theme/AppColors.dart';
import 'package:uuid/uuid.dart';
import 'package:shiftchart/services/audit_service.dart';
import 'package:shiftchart/models/audit_entry.dart';
import '../models/patient.dart';

class AddPatientScreen extends StatefulWidget {
  final Patient? patient;
  const AddPatientScreen({super.key, this.patient});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

final _roomControllerFocusNode = FocusNode();

class _AddPatientScreenState extends State<AddPatientScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  late final TextEditingController _notesController;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient?.name ?? '');
    _roomController = TextEditingController(text: widget.patient?.roomNumber ?? '');
    _notesController = TextEditingController(text: widget.patient?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _savePatient() async {
    final name = _nameController.text.trim();
    final room = _roomController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty || room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      if (widget.patient != null) {
        widget.patient!.name = name;
        widget.patient!.roomNumber = room;
        widget.patient!.notes = notes;
        await widget.patient!.save();
        
        AuditService.log(AuditAction.patientUpdated, {
          'id': widget.patient!.id,
          'name': name,
          'room': room,
          'indication': notes,
        }, outcome: true);
      } else {
        final newPatient = Patient(
          id: _uuid.v4(),
          name: name,
          roomNumber: room,
          status: PatientStatus.green,
          notes: notes,
          admissionDate: DateTime.now(),
        );
        await Hive.box<Patient>('patients').add(newPatient);
        
        AuditService.log(AuditAction.patientCreated, {
          'id': newPatient.id,
          'name': name,
          'room': room,
          'indication': notes,
        }, outcome: true);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AuditService.log(
        widget.patient != null ? AuditAction.patientUpdated : AuditAction.patientCreated,
        {
          'name': name,
          'error': e.toString(),
        },
        outcome: false,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving patient: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.patient == null ? 'New Patient' : 'Edit Patient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              // if enter is pressed focus on next field
              onSubmitted: (value) => FocusScope.of(context).requestFocus(_roomControllerFocusNode),
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              keyboardType: TextInputType.name,
              decoration: const InputDecoration(
                labelText: 'Patient Name',
                hintText: 'e.g. Sarah Jenkins',
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              focusNode: _roomControllerFocusNode,
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room Number',
                hintText: 'e.g. 302-A',
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Primary Indication',
                hintText: 'e.g., Sepsis secondary to pneumonia',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: PrimaryButton(
                label: 'Save Patient',
                onTap: _savePatient,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
