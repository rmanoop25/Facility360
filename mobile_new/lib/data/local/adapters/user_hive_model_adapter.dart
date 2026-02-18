import 'package:hive/hive.dart';
import 'user_hive_model.dart';

/// Manual TypeAdapter for UserHiveModel (typeId: 4)
class UserHiveModelAdapter extends TypeAdapter<UserHiveModel> {
  @override
  final int typeId = 4;

  @override
  UserHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return UserHiveModel(
      serverId: fields[0] as int,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String?,
      profilePhoto: fields[4] as String?,
      fcmToken: fields[5] as String?,
      locale: fields[6] as String,
      isActive: fields[7] as bool,
      rolesJson: fields[8] as String,
      permissionsJson: fields[9] as String,
      isTenant: fields[10] as bool?,
      isServiceProvider: fields[11] as bool?,
      isAdmin: fields[12] as bool?,
      tenantJson: fields[13] as String?,
      serviceProviderJson: fields[14] as String?,
      syncedAt: fields[15] as DateTime,
      fullDataJson: fields[16] as String?,
      isCurrentUser: fields[17] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserHiveModel obj) {
    writer
      ..writeByte(18) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.profilePhoto)
      ..writeByte(5)
      ..write(obj.fcmToken)
      ..writeByte(6)
      ..write(obj.locale)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.rolesJson)
      ..writeByte(9)
      ..write(obj.permissionsJson)
      ..writeByte(10)
      ..write(obj.isTenant)
      ..writeByte(11)
      ..write(obj.isServiceProvider)
      ..writeByte(12)
      ..write(obj.isAdmin)
      ..writeByte(13)
      ..write(obj.tenantJson)
      ..writeByte(14)
      ..write(obj.serviceProviderJson)
      ..writeByte(15)
      ..write(obj.syncedAt)
      ..writeByte(16)
      ..write(obj.fullDataJson)
      ..writeByte(17)
      ..write(obj.isCurrentUser);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
