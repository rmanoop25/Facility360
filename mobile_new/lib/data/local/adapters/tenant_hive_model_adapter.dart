import 'package:hive/hive.dart';
import 'tenant_hive_model.dart';

/// Manual TypeAdapter for TenantHiveModel (typeId: 5)
class TenantHiveModelAdapter extends TypeAdapter<TenantHiveModel> {
  @override
  final int typeId = 5;

  @override
  TenantHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return TenantHiveModel(
      serverId: fields[0] as int?,
      localId: fields[1] as String,
      userId: fields[2] as int?,
      unitNumber: fields[3] as String?,
      buildingName: fields[4] as String?,
      floor: fields[5] as String?,
      userName: fields[6] as String?,
      userEmail: fields[7] as String?,
      userPhone: fields[8] as String?,
      userIsActive: fields[9] as bool? ?? true,
      userLocale: fields[10] as String?,
      issuesCount: fields[11] as int?,
      syncStatus: fields[12] as String,
      createdAt: fields[13] as DateTime,
      syncedAt: fields[14] as DateTime?,
      fullDataJson: fields[15] as String?,
      isDeleted: fields[16] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, TenantHiveModel obj) {
    writer
      ..writeByte(17) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.localId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.unitNumber)
      ..writeByte(4)
      ..write(obj.buildingName)
      ..writeByte(5)
      ..write(obj.floor)
      ..writeByte(6)
      ..write(obj.userName)
      ..writeByte(7)
      ..write(obj.userEmail)
      ..writeByte(8)
      ..write(obj.userPhone)
      ..writeByte(9)
      ..write(obj.userIsActive)
      ..writeByte(10)
      ..write(obj.userLocale)
      ..writeByte(11)
      ..write(obj.issuesCount)
      ..writeByte(12)
      ..write(obj.syncStatus)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.syncedAt)
      ..writeByte(15)
      ..write(obj.fullDataJson)
      ..writeByte(16)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
