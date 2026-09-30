import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;
}

class AppEnvironment {
  const AppEnvironment({
    this.useEmulators = false,
    this.emulatorHost = '127.0.0.1',
  });

  factory AppEnvironment.fromDefines() => const AppEnvironment(
    useEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    emulatorHost: String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    ),
  );

  final bool useEmulators;
  final String emulatorHost;

  void validate() {
    if (useEmulators && !{'127.0.0.1', 'localhost'}.contains(emulatorHost)) {
      throw const ConfigurationException(
        'Режим емуляторів потребує локального host: 127.0.0.1 або localhost.',
      );
    }
  }

  FirebaseOptions get firebaseOptions {
    validate();
    // Resolve demo options first: emulator mode never evaluates platform config.
    if (useEmulators) {
      return const FirebaseOptions(
        apiKey: 'demo-dacha-local-key',
        appId: '1:1234567890:web:localdemo',
        messagingSenderId: '1234567890',
        projectId: 'demo-dacha',
        authDomain: 'demo-dacha.firebaseapp.com',
      );
    }
    return DefaultFirebaseOptions.currentPlatform;
  }
}
