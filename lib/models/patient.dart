import 'package:hive/hive.dart';
import 'medication.dart';

part 'patient.g.dart';

@HiveType(typeId: 2)
enum PatientStatus {
  @HiveField(0)
  green,
  @HiveField(1)
  yellow,
  @HiveField(2)
  red
}

@HiveType(typeId: 1)
class Patient extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String roomNumber;
  
  @HiveField(3)
  PatientStatus status;

  @HiveField(4)
  HiveList<Medication>? medications;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  DateTime? admissionDate;

  Patient({
    required this.id,
    required this.name,
    required this.roomNumber,
    this.status = PatientStatus.green,
    this.medications,
    this.notes,
    this.admissionDate,
  });
}
