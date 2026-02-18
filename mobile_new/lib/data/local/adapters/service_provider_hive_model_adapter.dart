import 'package:hive/hive.dart';
import 'service_provider_hive_model.dart';

/// Manual TypeAdapter for ServiceProviderHiveModel (typeId: 6)
class ServiceProviderHiveModelAdapter
    extends TypeAdapter<ServiceProviderHiveModel> {
  @override
  final int typeId = 6;

  @override
  ServiceProviderHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ServiceProviderHiveModel(
      serverId: fields[0] as int?,
      localId: fields[1] as String,
      userId: fields[2] as int?,
      categoryIds: (fields[3] as List?)?.cast<int>() ?? [],
      latitude: fields[4] as double?,
      longitude: fields[5] as double?,
      isAvailable: fields[6] as bool? ?? true,
      userName: fields[7] as String?,
      userEmail: fields[8] as String?,
      userPhone: fields[9] as String?,
      activeJobs: fields[10] as int? ?? 0,
      rating: fields[11] as double?,
      categoriesJson: fields[12] as String?,
      timeSlotsJson: fields[13] as String?,
      syncStatus: fields[14] as String,
      createdAt: fields[15] as DateTime,
      syncedAt: fields[16] as DateTime?,
      fullDataJson: fields[17] as String?,
      isDeleted: fields[18] as bool? ?? false,
      userIsActive: fields[19] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, ServiceProviderHiveModel obj) {
    writer
      ..writeByte(20) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.localId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.categoryIds)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.isAvailable)
      ..writeByte(7)
      ..write(obj.userName)
      ..writeByte(8)
      ..write(obj.userEmail)
      ..writeByte(9)
      ..write(obj.userPhone)
      ..writeByte(10)
      ..write(obj.activeJobs)
      ..writeByte(11)
      ..write(obj.rating)
      ..writeByte(12)
      ..write(obj.categoriesJson)
      ..writeByte(13)
      ..write(obj.timeSlotsJson)
      ..writeByte(14)
      ..write(obj.syncStatus)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.syncedAt)
      ..writeByte(17)
      ..write(obj.fullDataJson)
      ..writeByte(18)
      ..write(obj.isDeleted)
      ..writeByte(19)
      ..write(obj.userIsActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceProviderHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
