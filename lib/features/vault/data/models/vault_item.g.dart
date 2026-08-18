// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VaultItemAdapter extends TypeAdapter<VaultItem> {
  @override
  final int typeId = 0;

  @override
  VaultItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaultItem(
      id: fields[0] as String,
      title: fields[1] as String,
      usernameEncrypted: (fields[2] as String?) ?? '',
      passwordEncrypted: (fields[3] as String?) ?? '',
      iv: fields[4] as String,
      category: (fields[5] as String?) ?? 'General',
      notes: fields[6] as String?,
      isSynced: (fields[7] as bool?) ?? false,
      updatedAt: fields[8] as DateTime,
      accountNumber: fields[9] as String?,
      type: (fields[10] as String?) ?? 'login',
      cardDetailsEnc: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VaultItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.usernameEncrypted)
      ..writeByte(3)
      ..write(obj.passwordEncrypted)
      ..writeByte(4)
      ..write(obj.iv)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.accountNumber)
      ..writeByte(10)
      ..write(obj.type)
      ..writeByte(11)
      ..write(obj.cardDetailsEnc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
