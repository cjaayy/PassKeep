/// Encapsulates the output of an AES-256 encryption operation.
class EncryptionResult {
  /// Base64-encoded encrypted ciphertext.
  final String cipherTextBase64;

  /// Base64-encoded 16-byte Initialization Vector (IV).
  final String ivBase64;

  const EncryptionResult({
    required this.cipherTextBase64,
    required this.ivBase64,
  });

  Map<String, String> toMap() {
    return {
      'cipher_text': cipherTextBase64,
      'iv': ivBase64,
    };
  }

  factory EncryptionResult.fromMap(Map<String, dynamic> map) {
    return EncryptionResult(
      cipherTextBase64: (map['cipher_text'] ?? map['cipherTextBase64']) as String,
      ivBase64: (map['iv'] ?? map['ivBase64']) as String,
    );
  }

  @override
  String toString() => 'EncryptionResult(cipherText: $cipherTextBase64, iv: $ivBase64)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EncryptionResult &&
        other.cipherTextBase64 == cipherTextBase64 &&
        other.ivBase64 == ivBase64;
  }

  @override
  int get hashCode => cipherTextBase64.hashCode ^ ivBase64.hashCode;
}
