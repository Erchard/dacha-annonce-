import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dacha_annonce/core/config/app_environment.dart';
import 'package:dacha_annonce/core/config/firebase_bootstrap.dart';
import 'package:flutter/material.dart';

// Standalone browser smoke target: never deploy this test application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var result = 'FAIL';
  final environment = AppEnvironment.fromDefines();
  if (!environment.useEmulators) {
    runApp(const MaterialApp(home: Text('FAIL: emulator flag required')));
    return;
  }
  try {
    final services = await initializeFirebase(environment)
        .timeout(const Duration(seconds: 15));
    try {
      if (services.firestore.settings.persistenceEnabled != false ||
          services.firestore.app.options.projectId != 'demo-dacha') {
        throw StateError('Unexpected Firebase configuration');
      }
      await services.auth.signInAnonymously().timeout(
        const Duration(seconds: 15),
      );
      Future<void> mustDeny(Future<Object?> Function() action) async {
        try {
          await action().timeout(const Duration(seconds: 15));
          throw StateError('Rules unexpectedly allowed access');
        } on FirebaseException catch (error) {
          if (error.code != 'permission-denied') rethrow;
        }
      }

      await mustDeny(
        () => services.firestore
            .doc('bootstrap/smoke')
            .get(const GetOptions(source: Source.server)),
      );
      await mustDeny(
        () => services.firestore.doc('bootstrap/smoke').set({'value': true}),
      );
      result = 'PASS: FlutterFire Auth and Firestore emulators';
    } finally {
      await services.auth.currentUser?.delete();
      await services.auth.signOut();
      await services.firestore.terminate();
      await services.auth.app.delete();
    }
  } catch (error) {
    result = 'FAIL: ${error.runtimeType}';
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(result))),
    ),
  );
}
