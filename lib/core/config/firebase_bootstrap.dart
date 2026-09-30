import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

class FirebaseServices {
  const FirebaseServices({required this.auth, required this.firestore});
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
}

final firebaseServicesProvider = Provider<FirebaseServices>((ref) {
  throw StateError('Firebase services must be initialized before use.');
});

Future<FirebaseServices> initializeFirebase(AppEnvironment environment) async {
  // Select generated FlutterFire options or independent demo options before init.
  final options = environment.firebaseOptions;
  final app = await Firebase.initializeApp(options: options);
  final auth = FirebaseAuth.instanceFor(app: app);
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.settings = const Settings(persistenceEnabled: false);
  if (environment.useEmulators) {
    await auth.useAuthEmulator(environment.emulatorHost, 9099);
    firestore.useFirestoreEmulator(environment.emulatorHost, 8080);
  }
  await auth.setPersistence(Persistence.SESSION);
  return FirebaseServices(auth: auth, firestore: firestore);
}
