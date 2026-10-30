import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:medicine_archive/security/device_lock.dart';

class _FakePlatform extends LocalAuthPlatform {
  _FakePlatform(this.answer);
  final Future<bool> Function() answer;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) => answer();
}

void main() {
  test('a passed fingerprint or PIN unlocks', () async {
    LocalAuthPlatform.instance = _FakePlatform(() async => true);
    expect(await deviceLock()(), isTrue);
  });

  test('a cancelled prompt stays locked', () async {
    LocalAuthPlatform.instance = _FakePlatform(
      () => throw const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
    );
    expect(await deviceLock()(), isFalse);
  });

  test('a phone with no lock set up opens, so nobody is locked out', () async {
    LocalAuthPlatform.instance = _FakePlatform(
      () => throw const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet),
    );
    expect(await deviceLock()(), isTrue);
  });
}
