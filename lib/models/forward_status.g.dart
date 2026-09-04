// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual adapter for ForwardStatus (typeId: 1)

part of 'forward_status.dart';

class ForwardStatusAdapter extends TypeAdapter<ForwardStatus> {
  @override
  final int typeId = 1;

  @override
  ForwardStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ForwardStatus.pending;
      case 1:
        return ForwardStatus.sending;
      case 2:
        return ForwardStatus.sent;
      case 3:
        return ForwardStatus.failed;
      default:
        return ForwardStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ForwardStatus obj) {
    switch (obj) {
      case ForwardStatus.pending:
        writer.writeByte(0);
        break;
      case ForwardStatus.sending:
        writer.writeByte(1);
        break;
      case ForwardStatus.sent:
        writer.writeByte(2);
        break;
      case ForwardStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForwardStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
