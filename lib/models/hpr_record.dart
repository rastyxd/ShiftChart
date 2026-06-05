import 'package:hive/hive.dart';
import 'medication.dart';

part 'hpr_record.g.dart';

@HiveType(typeId: 4)
class HPRRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String patientId;

  @HiveField(2)
  final String patientName;

  @HiveField(3)
  final String roomNumber;

  @HiveField(4)
  final DateTime admissionDate;

  @HiveField(5)
  final DateTime dischargeDate;

  @HiveField(6)
  final List<HPREntry> entries;

  @HiveField(8)
  bool isBookmarked;

  @HiveField(9)
  String? notes;

  @HiveField(10)
  String? pdfPath;

  HPRRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.roomNumber,
    required this.admissionDate,
    required this.dischargeDate,
    required this.entries,
    this.notes,
    this.isBookmarked = false,
    this.pdfPath,
  });
}

@HiveType(typeId: 5)
class HPREntry {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String dose;

  @HiveField(2)
  final DateTime time;

  @HiveField(3)
  final MedType type;

  @HiveField(4)
  final String report;

  HPREntry({
    required this.name,
    required this.dose,
    required this.time,
    required this.type,
    required this.report,
  });

  factory HPREntry.fromMedication(Medication med) {
    String report = '';
    final status = med.isGiven ? 'Administered' : (med.isPrn ? 'Not Requested' : 'MISSED');
    
    if (med.type == MedType.medication) {
      report = '$status ${med.dose} of ${med.name}';
      if (med.route != null) {
        report += ' ${med.route}';
      }
      if (med.isDiluted) {
        report += ' Diluted in ${med.diluentVolume ?? 'standard volume'} of ${med.diluent ?? 'Normal Saline'}';
      }
    } else if (med.type == MedType.vitalCheck) {
      report = med.isGiven ? 'Performed ${med.name} check' : '$status ${med.name} check';
    } else if (med.type == MedType.ivFluid) {
      report = med.isGiven ? 'Started IV Fluid: ${med.name} at ${med.dose}' : '$status IV Fluid: ${med.name}';
      if (med.isDiluted && med.isGiven) {
        report += ' Diluted in ${med.diluentVolume} of ${med.diluent}';
      }
    }

    return HPREntry(
      name: med.name,
      dose: med.dose,
      time: med.timeDue,
      type: med.type,
      report: report,
    );
  }
}
