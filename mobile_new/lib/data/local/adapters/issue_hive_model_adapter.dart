import 'package:hive/hive.dart';
import 'issue_hive_model.dart';

/// Manual TypeAdapter for IssueHiveModel (typeId: 1)
class IssueHiveModelAdapter extends TypeAdapter<IssueHiveModel> {
  @override
  final int typeId = 1;

  @override
  IssueHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return IssueHiveModel(
      serverId: fields[0] as int?,
      localId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String?,
      status: fields[4] as String,
      priority: fields[5] as String,
      categoryIds: (fields[6] as List?)?.cast<int>() ?? [],
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      localMediaPaths: (fields[9] as List?)?.cast<String>() ?? [],
      syncStatus: fields[10] as String,
      createdAt: fields[11] as DateTime,
      syncedAt: fields[12] as DateTime?,
      tenantId: fields[13] as int?,
      fullDataJson: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IssueHiveModel obj) {
    writer
      ..writeByte(15) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.localId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.categoryIds)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.localMediaPaths)
      ..writeByte(10)
      ..write(obj.syncStatus)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.syncedAt)
      ..writeByte(13)
      ..write(obj.tenantId)
      ..writeByte(14)
      ..write(obj.fullDataJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
