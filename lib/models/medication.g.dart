// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicationAdapter extends TypeAdapter<Medication> {
  @override
  final int typeId = 0;

  @override
  Medication read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medication(
      id: fields[0] as String,
      name: fields[1] as String,
      dose: fields[2] as String,
      timeDue: fields[3] as DateTime,
      isGiven: fields[4] as bool,
      repeatValue: fields[5] as int?,
      isRepeatInMinutes: fields[6] as bool,
      type: fields[7] as MedType,
      route: fields[8] as String?,
      isDiluted: fields[9] as bool,
      diluent: fields[10] as String?,
      diluentVolume: fields[11] as String?,
      isPrn: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Medication obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dose)
      ..writeByte(3)
      ..write(obj.timeDue)
      ..writeByte(4)
      ..write(obj.isGiven)
      ..writeByte(5)
      ..write(obj.repeatValue)
      ..writeByte(6)
      ..write(obj.isRepeatInMinutes)
      ..writeByte(7)
      ..write(obj.type)
      ..writeByte(8)
      ..write(obj.route)
      ..writeByte(9)
      ..write(obj.isDiluted)
      ..writeByte(10)
      ..write(obj.diluent)
      ..writeByte(11)
      ..write(obj.diluentVolume)
      ..writeByte(12)
      ..write(obj.isPrn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedTypeAdapter extends TypeAdapter<MedType> {
  @override
  final int typeId = 3;

  @override
  MedType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedType.medication;
      case 1:
        return MedType.vitalCheck;
      case 2:
        return MedType.ivFluid;
      default:
        return MedType.medication;
    }
  }

  @override
  void write(BinaryWriter writer, MedType obj) {
    switch (obj) {
      case MedType.medication:
        writer.writeByte(0);
        break;
      case MedType.vitalCheck:
        writer.writeByte(1);
        break;
      case MedType.ivFluid:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
