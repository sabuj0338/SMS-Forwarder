// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual adapter for QueuedSms (typeId: 2)

part of 'queued_sms.dart';

class QueuedSmsAdapter extends TypeAdapter<QueuedSms> {
  @override
  final int typeId = 2;

  @override
  QueuedSms read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QueuedSms(
      id: fields[0] as String,
      sender: fields[1] as String,
      body: fields[2] as String,
      receivedAt: fields[3] as DateTime,
      status: fields[4] as ForwardStatus,
      attempts: fields[5] as int,
      lastError: fields[6] as String?,
      forwardedAt: fields[7] as DateTime?,
      payloadHash: fields[8] as String,
      nextRetryAt: fields[9] as DateTime?,
      amount: (fields[10] as num?)?.toDouble(),
      txnId: fields[11] as String?,
      txnType: fields[12] as String?,
      counterparty: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QueuedSms obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sender)
      ..writeByte(2)
      ..write(obj.body)
      ..writeByte(3)
      ..write(obj.receivedAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.attempts)
      ..writeByte(6)
      ..write(obj.lastError)
      ..writeByte(7)
      ..write(obj.forwardedAt)
      ..writeByte(8)
      ..write(obj.payloadHash)
      ..writeByte(9)
      ..write(obj.nextRetryAt)
      ..writeByte(10)
      ..write(obj.amount)
      ..writeByte(11)
      ..write(obj.txnId)
      ..writeByte(12)
      ..write(obj.txnType)
      ..writeByte(13)
      ..write(obj.counterparty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedSmsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
