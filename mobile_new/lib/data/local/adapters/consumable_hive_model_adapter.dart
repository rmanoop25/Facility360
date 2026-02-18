import 'package:hive/hive.dart';
import 'consumable_hive_model.dart';

/// Manual TypeAdapter for ConsumableHiveModel (typeId: 8)
class ConsumableHiveModelAdapter extends TypeAdapter<ConsumableHiveModel> {
  @override
  final int typeId = 8;

  @override
  ConsumableHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ConsumableHiveModel(
      serverId: fields[0] as int,
      categoryId: fields[1] as int?,
      nameEn: fields[2] as String,
      nameAr: fields[3] as String,
      isActive: fields[4] as bool,
      syncedAt: fields[5] as DateTime,
      fullDataJson: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConsumableHiveModel obj) {
    writer
      ..writeByte(7) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.nameEn)
      ..writeByte(3)
      ..write(obj.nameAr)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.syncedAt)
      ..writeByte(6)
      ..write(obj.fullDataJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumableHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
