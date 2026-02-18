import 'package:hive/hive.dart';
import 'work_type_hive_model.dart';

/// Manual TypeAdapter for WorkTypeHiveModel (typeId: 13)
class WorkTypeHiveModelAdapter extends TypeAdapter<WorkTypeHiveModel> {
  @override
  final int typeId = 13;

  @override
  WorkTypeHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return WorkTypeHiveModel(
      serverId: fields[0] as int,
      nameEn: fields[1] as String,
      nameAr: fields[2] as String,
      descriptionEn: fields[3] as String?,
      descriptionAr: fields[4] as String?,
      durationMinutes: fields[5] as int,
      isActive: (fields[6] as bool?) ?? true,
      categoryIds: (fields[7] as List?)?.cast<int>() ?? [],
      syncedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorkTypeHiveModel obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.nameEn)
      ..writeByte(2)
      ..write(obj.nameAr)
      ..writeByte(3)
      ..write(obj.descriptionEn)
      ..writeByte(4)
      ..write(obj.descriptionAr)
      ..writeByte(5)
      ..write(obj.durationMinutes)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.categoryIds)
      ..writeByte(8)
      ..write(obj.syncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkTypeHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
