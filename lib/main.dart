import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/config/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Preserve the deep link before the temporary loading app mounts.
  final initialLocation =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(const StartupApp());
  try {
    final environment = AppEnvironment.fromDefines();
    environment.validate();
    tz.initializeTimeZones();
    final services = await initializeFirebase(environment)
        .timeout(const Duration(seconds: 20));
    runApp(
      ProviderScope(
        overrides: [firebaseServicesProvider.overrideWithValue(services)],
        child: DachaApp(router: createRouter(initialLocation: initialLocation)),
      ),
    );
  } on ConfigurationException catch (error) {
    runApp(StartupApp(error: error.message));
  } catch (_) {
    runApp(
      const StartupApp(
        error: 'Не вдалося підготувати підключення. Перевірте мережу, налаштування Firebase та запуск локальних емуляторів, потім оновіть сторінку.',
      ),
    );
  }
}
