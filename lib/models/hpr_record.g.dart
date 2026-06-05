// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hpr_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HPRRecordAdapter extends TypeAdapter<HPRRecord> {
  @override
  final int typeId = 4;

  @override
  HPRRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HPRRecord(
      id: fields[0] as String,
      patientId: fields[1] as String,
      patientName: fields[2] as String,
      roomNumber: fields[3] as String,
      admissionDate: fields[4] as DateTime,
      dischargeDate: fields[5] as DateTime,
      entries: (fields[6] as List).cast<HPREntry>(),
      notes: fields[9] as String?,
      isBookmarked: fields[8] as bool,
      pdfPath: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HPRRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientId)
      ..writeByte(2)
      ..write(obj.patientName)
      ..writeByte(3)
      ..write(obj.roomNumber)
      ..writeByte(4)
      ..write(obj.admissionDate)
      ..writeByte(5)
      ..write(obj.dischargeDate)
      ..writeByte(6)
      ..write(obj.entries)
      ..writeByte(8)
      ..write(obj.isBookmarked)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.pdfPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HPRRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HPREntryAdapter extends TypeAdapter<HPREntry> {
  @override
  final int typeId = 5;

  @override
  HPREntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HPREntry(
      name: fields[0] as String,
      dose: fields[1] as String,
      time: fields[2] as DateTime,
      type: fields[3] as MedType,
      report: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HPREntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.dose)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.report);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HPREntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
