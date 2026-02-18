import 'package:hive/hive.dart';
import 'sync_operation.dart';

/// Manual TypeAdapter for SyncOperation (typeId: 10)
/// Created manually due to riverpod_generator/hive_generator conflict
class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 10;

  @override
  SyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SyncOperation(
      id: fields[0] as String,
      operationType: fields[1] as String,
      entityType: fields[2] as String,
      localId: fields[3] as String,
      dataJson: fields[4] as String,
      createdAt: fields[5] as DateTime,
      retryCount: fields[6] as int? ?? 0,
      lastAttempt: fields[7] as DateTime?,
      lastError: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    writer
      ..writeByte(9) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.operationType)
      ..writeByte(2)
      ..write(obj.entityType)
      ..writeByte(3)
      ..write(obj.localId)
      ..writeByte(4)
      ..write(obj.dataJson)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.retryCount)
      ..writeByte(7)
      ..write(obj.lastAttempt)
      ..writeByte(8)
      ..write(obj.lastError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
