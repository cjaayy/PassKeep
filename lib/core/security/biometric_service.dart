/// Interface for biometric authentication via LocalAuth
abstract class IBiometricService {
  /// Checks whether biometrics (fingerprint/face) are supported and enrolled on the device.
  Future<bool> canAuthenticateWithBiometrics();

  /// Prompts the user for biometric authentication.
  Future<bool> authenticate({required String localizedReason});
}
