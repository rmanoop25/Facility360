import 'package:hive/hive.dart';
import 'category_hive_model.dart';

/// Manual TypeAdapter for CategoryHiveModel (typeId: 7)
/// Updated to support hierarchy fields (14-19)
class CategoryHiveModelAdapter extends TypeAdapter<CategoryHiveModel> {
  @override
  final int typeId = 7;

  @override
  CategoryHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CategoryHiveModel(
      serverId: fields[0] as int,
      nameEn: fields[1] as String,
      nameAr: fields[2] as String,
      descriptionEn: fields[3] as String?,
      descriptionAr: fields[4] as String?,
      icon: fields[5] as String?,
      color: fields[6] as String?,
      sortOrder: fields[7] as int,
      isActive: fields[8] as bool,
      syncedAt: fields[9] as DateTime,
      fullDataJson: fields[10] as String?,
      consumablesCount: fields[11] as int?,
      serviceProvidersCount: fields[12] as int?,
      issuesCount: fields[13] as int?,
      // Hierarchy fields (with defaults for backward compatibility)
      parentId: fields[14] as int?,
      depth: (fields[15] as int?) ?? 0,
      path: fields[16] as String?,
      isRoot: (fields[17] as bool?) ?? true,
      childrenCount: fields[18] as int?,
      hasChildren: fields[19] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryHiveModel obj) {
    writer
      ..writeByte(20) // number of fields (updated from 14 to 20)
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
      ..write(obj.icon)
      ..writeByte(6)
      ..write(obj.color)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.syncedAt)
      ..writeByte(10)
      ..write(obj.fullDataJson)
      ..writeByte(11)
      ..write(obj.consumablesCount)
      ..writeByte(12)
      ..write(obj.serviceProvidersCount)
      ..writeByte(13)
      ..write(obj.issuesCount)
      // Hierarchy fields
      ..writeByte(14)
      ..write(obj.parentId)
      ..writeByte(15)
      ..write(obj.depth)
      ..writeByte(16)
      ..write(obj.path)
      ..writeByte(17)
      ..write(obj.isRoot)
      ..writeByte(18)
      ..write(obj.childrenCount)
      ..writeByte(19)
      ..write(obj.hasChildren);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
