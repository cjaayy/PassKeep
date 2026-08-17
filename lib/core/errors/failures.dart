/// Base failure class for domain and data layer error handling
abstract class Failure implements Exception {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class SecurityFailure extends Failure {
  const SecurityFailure([super.message = 'Security or cryptographic operation failed']);
}

class EncryptionFailure extends Failure {
  const EncryptionFailure([super.message = 'Failed to encrypt data']);
}

class DecryptionFailure extends Failure {
  const DecryptionFailure([super.message = 'Failed to decrypt data. Invalid key, corrupted payload, or tampered IV.']);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Local database operation failed']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class SyncFailure extends Failure {
  const SyncFailure([super.message = 'Cloud synchronization failed']);
}
