import '../features/support/support_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/firebase_bootstrap.dart';
import '../features/auth/domain/user_profile.dart';
import '../features/bookings/data/booking_service.dart';
import 'data/app_repository.dart';

final repositoryProvider = Provider<AppRepository>((ref) {
  final services = ref.watch(firebaseServicesProvider);
  return AppRepository(services.firestore, services.auth);
});
final authRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  final services = ref.watch(firebaseServicesProvider);
  return FirebaseAuthRepository(services.auth, services.firestore);
});
final bookingServiceProvider = Provider<BookingService>((ref) {
  final services = ref.watch(firebaseServicesProvider);
  return BookingService(services.firestore, services.auth);
});
final sessionProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authRepositoryProvider).session,
);
final profileProvider = StreamProvider<UserProfile?>((ref) async* {
  final session = ref.watch(sessionProvider);
  if (session.isLoading) return;
  if (session.hasError) throw session.error!;
  if (session.asData?.value == null) {
    yield null;
    return;
  }
  yield* ref.watch(repositoryProvider).watchMyProfile();
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final services = ref.watch(firebaseServicesProvider);
  return SupportRepository(services.firestore, services.auth);
});
