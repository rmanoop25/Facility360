import 'package:hive/hive.dart';
import 'assignment_hive_model.dart';

/// Manual TypeAdapter for AssignmentHiveModel (typeId: 2)
class AssignmentHiveModelAdapter extends TypeAdapter<AssignmentHiveModel> {
  @override
  final int typeId = 2;

  @override
  AssignmentHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AssignmentHiveModel(
      serverId: fields[0] as int?,
      localId: fields[1] as String,
      issueId: fields[2] as int,
      serviceProviderId: fields[3] as int,
      categoryId: fields[4] as int,
      status: fields[5] as String,
      scheduledDate: fields[6] as DateTime?,
      timeSlotId: fields[7] as int?,
      startedAt: fields[8] as DateTime?,
      heldAt: fields[9] as DateTime?,
      resumedAt: fields[10] as DateTime?,
      finishedAt: fields[11] as DateTime?,
      notes: fields[12] as String?,
      localProofPaths: (fields[13] as List?)?.cast<String>() ?? [],
      consumablesJson: fields[14] as String?,
      syncStatus: fields[15] as String,
      createdAt: fields[16] as DateTime,
      syncedAt: fields[17] as DateTime?,
      fullDataJson: fields[18] as String?,
      issueTitle: fields[19] as String?,
      tenantAddress: fields[20] as String?,
      assignedStartTime: fields[21] as String?,
      assignedEndTime: fields[22] as String?,
      timeSlotIdsJson: fields[23] as String?,
      scheduledEndDate: fields[24] as String?,
      isMultiDay: fields[25] as bool? ?? false,
      spanDays: fields[26] as int? ?? 1,
      timeSlotsJson: fields[27] as String?,
      workTypeId: fields[28] as int?,
      allocatedDurationMinutes: fields[29] as int?,
      isCustomDuration: fields[30] as bool? ?? false,
      extensionRequestsJson: fields[31] as String?,
      approvedExtensionMinutes: fields[32] as int? ?? 0,
      hasPendingExtension: fields[33] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AssignmentHiveModel obj) {
    writer
      ..writeByte(34) // number of fields
      ..writeByte(0)
      ..write(obj.serverId)
      ..writeByte(1)
      ..write(obj.localId)
      ..writeByte(2)
      ..write(obj.issueId)
      ..writeByte(3)
      ..write(obj.serviceProviderId)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.scheduledDate)
      ..writeByte(7)
      ..write(obj.timeSlotId)
      ..writeByte(8)
      ..write(obj.startedAt)
      ..writeByte(9)
      ..write(obj.heldAt)
      ..writeByte(10)
      ..write(obj.resumedAt)
      ..writeByte(11)
      ..write(obj.finishedAt)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.localProofPaths)
      ..writeByte(14)
      ..write(obj.consumablesJson)
      ..writeByte(15)
      ..write(obj.syncStatus)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.syncedAt)
      ..writeByte(18)
      ..write(obj.fullDataJson)
      ..writeByte(19)
      ..write(obj.issueTitle)
      ..writeByte(20)
      ..write(obj.tenantAddress)
      ..writeByte(21)
      ..write(obj.assignedStartTime)
      ..writeByte(22)
      ..write(obj.assignedEndTime)
      ..writeByte(23)
      ..write(obj.timeSlotIdsJson)
      ..writeByte(24)
      ..write(obj.scheduledEndDate)
      ..writeByte(25)
      ..write(obj.isMultiDay)
      ..writeByte(26)
      ..write(obj.spanDays)
      ..writeByte(27)
      ..write(obj.timeSlotsJson)
      ..writeByte(28)
      ..write(obj.workTypeId)
      ..writeByte(29)
      ..write(obj.allocatedDurationMinutes)
      ..writeByte(30)
      ..write(obj.isCustomDuration)
      ..writeByte(31)
      ..write(obj.extensionRequestsJson)
      ..writeByte(32)
      ..write(obj.approvedExtensionMinutes)
      ..writeByte(33)
      ..write(obj.hasPendingExtension);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
