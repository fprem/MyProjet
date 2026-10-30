import 'package:local_auth/local_auth.dart';

import 'app_lock.dart';

/// Unlocks with the phone's own lock: fingerprint, face, PIN or pattern.
///
/// When the phone has no lock set up there is nothing to check against, so
/// the app opens, as the phone itself does.
Authenticate deviceLock([LocalAuthentication? auth]) {
  final local = auth ?? LocalAuthentication();
  return () async {
    try {
      return await local.authenticate(
        localizedReason: 'Unlock your medicine archive',
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet;
    }
  };
}
