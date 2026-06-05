import 'package:hive/hive.dart';

part 'medication.g.dart';

@HiveType(typeId: 3)
enum MedType {
  @HiveField(0)
  medication,
  @HiveField(1)
  vitalCheck,
  @HiveField(2)
  ivFluid,
}

@HiveType(typeId: 0)
class Medication extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String dose;
  
  @HiveField(3)
  DateTime timeDue;
  
  @HiveField(4)
  bool isGiven;
  
  @HiveField(5)
  int? repeatValue;

  @HiveField(6)
  bool isRepeatInMinutes;

  @HiveField(7)
  final MedType type;

  @HiveField(8)
  String? route;

  @HiveField(9)
  bool isDiluted;

  @HiveField(10)
  String? diluent;

  @HiveField(11)
  String? diluentVolume;

  @HiveField(12)
  bool isPrn;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.timeDue,
    this.isGiven = false,
    this.repeatValue,
    this.isRepeatInMinutes = false,
    this.type = MedType.medication,
    this.route,
    this.isDiluted = false,
    this.diluent,
    this.diluentVolume,
    this.isPrn = false,
  });

  bool get isOverdue {
    if (isGiven || isPrn) return false;
    final now = DateTime.now();
    // Overdue only if the current time is at least 1 minute past the due time
    // This prevents tasks appearing red immediately due to seconds/milliseconds difference
    final duePlusOne = timeDue.add(const Duration(minutes: 1));
    return now.isAfter(duePlusOne) || (now.hour == timeDue.hour && now.minute > timeDue.minute && now.day == timeDue.day);
  }

  bool get isDueSoon {
    if (isGiven || isOverdue) return false;
    final now = DateTime.now();
    final diff = timeDue.difference(now).inMinutes;
    return diff <= 5;
  }
}
