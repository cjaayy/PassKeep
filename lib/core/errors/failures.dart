/// Base failure class for domain and data layer error handling
abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class SecurityFailure extends Failure {
  const SecurityFailure([super.message = 'Security or encryption operation failed']);
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
