import 'package:hive/hive.dart';
import 'notification_hive_model.dart';

/// Manual TypeAdapter for NotificationHiveModel (typeId: 3)
class NotificationHiveModelAdapter extends TypeAdapter<NotificationHiveModel> {
  @override
  final int typeId = 3;

  @override
  NotificationHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return NotificationHiveModel(
      id: fields[0] as String,
      title: fields[1] as String,
      body: fields[2] as String,
      type: fields[3] as String?,
      issueId: fields[4] as int?,
      dataJson: fields[5] as String?,
      receivedAt: fields[6] as DateTime,
      isRead: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationHiveModel obj) {
    writer
      ..writeByte(8) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.issueId)
      ..writeByte(5)
      ..write(obj.dataJson)
      ..writeByte(6)
      ..write(obj.receivedAt)
      ..writeByte(7)
      ..write(obj.isRead);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
