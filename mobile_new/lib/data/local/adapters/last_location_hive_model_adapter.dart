import 'package:hive/hive.dart';
import 'last_location_hive_model.dart';

/// Manual TypeAdapter for LastLocationHiveModel (typeId: 12)
class LastLocationHiveModelAdapter extends TypeAdapter<LastLocationHiveModel> {
  @override
  final int typeId = 12;

  @override
  LastLocationHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return LastLocationHiveModel(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      address: fields[2] as String?,
      capturedAt: fields[3] as DateTime,
      userId: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LastLocationHiveModel obj) {
    writer
      ..writeByte(5) // number of fields
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.capturedAt)
      ..writeByte(4)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LastLocationHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
