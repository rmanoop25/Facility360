import 'package:hive/hive.dart';
import 'time_slot_hive_model.dart';

/// Manual TypeAdapter for TimeSlotHiveModel (typeId: 9)
class TimeSlotHiveModelAdapter extends TypeAdapter<TimeSlotHiveModel> {
  @override
  final int typeId = 9;

  @override
  TimeSlotHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return TimeSlotHiveModel(
      serverId: fields[0] as int,
      serviceProviderId: fields[1] as int?,
      dayOfWeek: fields[2] as int,
      startTime: fields[3] as String,
      endTime: fields[4] as String,
      isActive: fields[5] as bool,
      syncedAt: fields[6] as DateTime,
      fullDataJson: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TimeSlotHiveModel obj) {
    writer
      ..writeByte(8) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.serviceProviderId)
      ..writeByte(2)
      ..write(obj.dayOfWeek)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.syncedAt)
      ..writeByte(7)
      ..write(obj.fullDataJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
