import '../features/support/support_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/firebase_bootstrap.dart';
import '../core/domain/page.dart';
import '../features/auth/domain/user_profile.dart';
import '../features/bookings/data/booking_service.dart';
import '../features/bookings/domain/booking.dart';
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

/// Pending booking count for admin nav badges (capped display).
final pendingBookingsCountProvider = FutureProvider<int>((ref) async {
  final profile = ref.watch(profileProvider).asData?.value;
  if (profile == null ||
      profile.isDisabled ||
      profile.role != UserRole.admin) {
    return 0;
  }
  final page = await ref.read(repositoryProvider).listBookings(
        PageRequest(limit: 25),
        forAdmin: true,
        status: BookingStatus.pending,
      );
  return page.items.length;
});

/// Open support tickets (new + in_progress) for staff nav badges.
final openTicketsCountProvider = FutureProvider<int>((ref) async {
  final profile = ref.watch(profileProvider).asData?.value;
  if (profile == null ||
      profile.isDisabled ||
      (profile.role != UserRole.admin &&
          profile.role != UserRole.developer)) {
    return 0;
  }
  final repo = ref.read(supportRepositoryProvider);
  final fresh = await repo.list(PageRequest(limit: 25), status: 'new');
  final active =
      await repo.list(PageRequest(limit: 25), status: 'in_progress');
  return fresh.items.length + active.items.length;
});
