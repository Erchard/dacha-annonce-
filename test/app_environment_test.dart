import 'package:dacha_annonce/core/config/app_environment.dart';
import 'package:dacha_annonce/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Normal mode needs no manually supplied Firebase parameters', () {
    const environment = AppEnvironment();
    expect(environment.useEmulators, isFalse);
    expect(environment.validate, returnsNormally);
    expect(DefaultFirebaseOptions.web.projectId, 'dacha-annonce');
  });

  test('Normal mode delegates platform selection to FlutterFire', () {
    const environment = AppEnvironment();
    if (kIsWeb) {
      expect(
        environment.firebaseOptions,
        same(DefaultFirebaseOptions.currentPlatform),
      );
    } else {
      // FlutterFire configured only web. Native VM tests must not silently use
      // web options or fake production options on an unsupported platform.
      expect(() => environment.firebaseOptions, throwsUnsupportedError);
    }
  });

  test('Emulators work without production parameters or platform support', () {
    for (final host in ['127.0.0.1', 'localhost']) {
      final environment = AppEnvironment(
        useEmulators: true,
        emulatorHost: host,
      );
      expect(environment.firebaseOptions.projectId, 'demo-dacha');
      expect(environment.firebaseOptions.apiKey, 'demo-dacha-local-key');
      expect(
        environment.firebaseOptions.appId,
        isNot(DefaultFirebaseOptions.web.appId),
      );
    }
  });

  test(
    'Remote or malformed emulator hosts are rejected before initialization',
    () {
      for (final host in [
        '',
        'example.org',
        'https://localhost',
        '127.0.0.1:8080',
      ]) {
        final environment = AppEnvironment(
          useEmulators: true,
          emulatorHost: host,
        );
        expect(
          () => environment.firebaseOptions,
          throwsA(isA<ConfigurationException>()),
        );
      }
    },
  );

  test('Compile-time switch selects emulator mode explicitly', () {
    expect(
      AppEnvironment.fromDefines().useEmulators,
      const bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    );
  });
}
