// Runs only against a freshly seeded demo-dacha Emulator. Never ship this target.
import 'package:dacha_annonce/app/data/app_repository.dart';
import 'package:dacha_annonce/core/config/app_environment.dart';
import 'package:dacha_annonce/core/config/firebase_bootstrap.dart';
import 'package:dacha_annonce/core/domain/page.dart';
import 'package:dacha_annonce/core/errors/domain_exception.dart';
import 'package:dacha_annonce/core/time/booking_time.dart';
import 'package:dacha_annonce/features/bookings/data/booking_service.dart';
import 'package:dacha_annonce/features/bookings/domain/booking.dart';
import 'package:dacha_annonce/features/support/support_repository.dart';
import 'package:flutter/material.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String result;
  String stage = 'bootstrap';
  try {
    final env = AppEnvironment.fromDefines();
    if (!env.useEmulators) throw StateError('Probe requires local emulators');
    final services = await initializeFirebase(env),
        db = services.firestore,
        auth = services.auth;
    final engine = BookingService(db, auth),
        repo = AppRepository(db, auth),
        support = SupportRepository(db, auth);
    Future<void> login(String name) => auth.signInWithEmailAndPassword(
      email: '$name@example.test',
      password: 'LocalDemo123!',
    );
    Future<void> rejected(
      Future<void> Function() operation,
      ErrorCode expected,
    ) async {
      try {
        await operation();
        throw StateError('Expected $expected');
      } on DomainException catch (e) {
        check(e.code == expected, 'Expected $expected, got ${e.code}');
      }
    }

    stage = 'organizer pending';
    await login('organizer');
    check(auth.currentUser!.emailVerified, 'seed verified');
    final start = DateTime.fromMillisecondsSinceEpoch(
      (DateTime.now().millisecondsSinceEpoch ~/ 21600000 + 20) * 21600000 +
          18000000,
      isUtc: true,
    );
    BookingDraft draft(String room, DateTime at) => BookingDraft(
      roomId: room,
      title: 'Flutter наскрізна перевірка',
      description: 'Подія створена справжнім Flutter-клієнтом.',
      interval: BookingInterval(at, at.add(const Duration(hours: 6))),
    );
    final id = engine.newId();
    await engine.execute(
      id,
      BookingAction.createPending,
      expectedVersion: 0,
      draft: draft('room-a', start),
    );
    check(
      (await repo.listBookings(PageRequest())).items.any((b) => b.id == id),
      'own query',
    );
    check(await repo.getPublishedEvent(id) == null, 'pending private');
    stage = 'admin approve';
    await login('admin');
    await engine.execute(id, BookingAction.approve, expectedVersion: 1);
    check(
      (await repo.getPublishedEvent(id))!.title ==
          'Flutter наскрізна перевірка',
      'public projection',
    );
    final conflict = engine.newId();
    await rejected(
      () => engine.execute(
        conflict,
        BookingAction.createApproved,
        expectedVersion: 0,
        draft: draft('room-a', start),
      ),
      ErrorCode.bookingConflict,
    );
    await rejected(
      () => engine.execute(id, BookingAction.cancel, expectedVersion: 1),
      ErrorCode.staleVersion,
    );
    stage = 'four-block reschedule';
    final moved = draft('room-b', start.add(const Duration(days: 1)));
    await engine.execute(
      id,
      BookingAction.reschedule,
      expectedVersion: 2,
      draft: moved,
    );
    for (final block in draft('room-a', start).interval.blockIds) {
      final d = (await db.doc('rooms/room-a/occupancy/$block').get()).data()!;
      check(!(d['slots'] as Map).values.contains(id), 'old lock released');
    }
    stage = 'owner cancel';
    await login('organizer');
    await engine.execute(id, BookingAction.cancel, expectedVersion: 3);
    check(await repo.getPublishedEvent(id) == null, 'cancel removes public');
    check(
      (await db
                  .collection('bookings')
                  .doc(id)
                  .collection('history')
                  .limit(10)
                  .get())
              .size ==
          4,
      'atomic history',
    );
    stage = 'support lifecycle';
    await login('admin');
    final ticket = support.newId();
    await support.create(
      ticket,
      type: 'bug',
      title: 'Наскрізна перевірка',
      body: 'Перевіряємо звернення зі справжнього клієнта.',
    );
    await login('developer');
    await support.status((await support.get(ticket))!, 'accepted');
    await support.status((await support.get(ticket))!, 'in_progress');
    await support.status((await support.get(ticket))!, 'done');
    await login('admin');
    await support.status(
      (await support.get(ticket))!,
      'accepted',
      comment: 'Потрібно уточнення після перевірки.',
    );
    check(
      (await support.entries(ticket, 'comments', PageRequest())).items.length ==
          1,
      'atomic comment',
    );
    check(
      (await support.entries(ticket, 'history', PageRequest())).items.length ==
          5,
      'support history',
    );
    stage = 'room audit';
    final room = (await repo.listRooms(PageRequest())).items.first;
    await repo.archive(room.id, expectedRevision: room.revision);
    check(
      (await repo.listRooms(PageRequest())).items.every((r) => r.id != room.id),
      'archive query',
    );
    check(
      await repo.getPublishedEvent('demo-event') != null,
      'archive preserves published snapshot',
    );
    await auth.signOut();
    result = 'PASS: Flutter booking, support, audit and role journeys';
  } catch (e) {
    result = 'FAIL at $stage: $e';
  }
  runApp(MaterialApp(home: Scaffold(body: Text(result))));
}
