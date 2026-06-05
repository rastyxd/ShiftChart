// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patient.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PatientAdapter extends TypeAdapter<Patient> {
  @override
  final int typeId = 1;

  @override
  Patient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Patient(
      id: fields[0] as String,
      name: fields[1] as String,
      roomNumber: fields[2] as String,
      status: fields[3] as PatientStatus,
      medications: (fields[4] as HiveList?)?.castHiveList(),
      notes: fields[5] as String?,
      admissionDate: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Patient obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.roomNumber)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.medications)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.admissionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PatientStatusAdapter extends TypeAdapter<PatientStatus> {
  @override
  final int typeId = 2;

  @override
  PatientStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PatientStatus.green;
      case 1:
        return PatientStatus.yellow;
      case 2:
        return PatientStatus.red;
      default:
        return PatientStatus.green;
    }
  }

  @override
  void write(BinaryWriter writer, PatientStatus obj) {
    switch (obj) {
      case PatientStatus.green:
        writer.writeByte(0);
        break;
      case PatientStatus.yellow:
        writer.writeByte(1);
        break;
      case PatientStatus.red:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatientStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
