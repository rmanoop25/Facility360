import 'package:hive/hive.dart';
import 'dashboard_stats_hive_model.dart';

/// Manual TypeAdapter for DashboardStatsHiveModel (typeId: 11)
class DashboardStatsHiveModelAdapter
    extends TypeAdapter<DashboardStatsHiveModel> {
  @override
  final int typeId = 11;

  @override
  DashboardStatsHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return DashboardStatsHiveModel(
      statsJson: fields[0] as String,
      cachedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DashboardStatsHiveModel obj) {
    writer
      ..writeByte(2) // number of fields
      ..writeByte(0)
      ..write(obj.statsJson)
      ..writeByte(1)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardStatsHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
