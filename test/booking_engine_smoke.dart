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
    final organizerUid = auth.currentUser!.uid;
    final start = DateTime.fromMillisecondsSinceEpoch(
      (DateTime.now().millisecondsSinceEpoch ~/ 21600000 + 20) * 21600000 +
          18000000,
      isUtc: true,
    );
    BookingDraft draft(String room, DateTime at) => BookingDraft(
      roomId: room,
      title: 'Flutter наскрізна перевірка',
      description: 'Подія створена справжнім Flutter-клієнтом.',
      contactPhone: '+380 00 000 00 00',
      notes: 'Перевірка примітки',
      directions: ['Культура', 'Для дітей'],
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
    final published = (await repo.getPublishedEvent(id))!;
    check(
      published.contactPhone == '+380 00 000 00 00' &&
          published.notes == 'Перевірка примітки' &&
          published.directions.length == 2,
      'schedule fields round trip',
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
    stage = 'delete and trusted publishing';
    await login('admin');
    await engine.execute(id, BookingAction.delete, expectedVersion: 4);
    check(await repo.getBooking(id) == null, 'deleted detail unavailable');
    final organizerProfile =
        (await db.collection('users').doc(organizerUid).get()).data()!;
    await repo.setPublishing(
      organizerUid,
      true,
      expectedRevision: organizerProfile['adminRevision'] as int,
    );
    await login('organizer');
    final token = engine.newId();
    final seriesIds = ['$token-20261020', '$token-20261027'];
    for (var i = 0; i < seriesIds.length; i++) {
      await engine.execute(
        seriesIds[i],
        BookingAction.createApproved,
        expectedVersion: 0,
        draft: draft('room-b', start.add(Duration(days: 14 + i * 7))),
      );
    }
    final occurrences = await engine.seriesOccurrences(seriesIds.first);
    check(occurrences.length == 2, 'own series query');
    for (final occurrence in occurrences) {
      await engine.execute(
        occurrence.id,
        BookingAction.delete,
        expectedVersion: occurrence.version,
      );
    }
    check(
      (await engine.seriesOccurrences(seriesIds.first)).isEmpty,
      'series retry excludes deleted',
    );
    check(
      (await repo.listBookings(PageRequest())).items
          .every((b) => !seriesIds.contains(b.id)),
      'deleted absent from list',
    );
    await login('admin');
    final currentProfile =
        (await db.collection('users').doc(organizerUid).get()).data()!;
    await repo.setPublishing(
      organizerUid,
      false,
      expectedRevision: currentProfile['adminRevision'] as int,
    );
    await login('organizer');
    await rejected(
      () => engine.execute(
        engine.newId(),
        BookingAction.createApproved,
        expectedVersion: 0,
        draft: draft('room-b', start.add(const Duration(days: 40))),
      ),
      ErrorCode.permissionDenied,
    );
    await login('admin');
    final spare = (await repo.getRoom('room-b'))!;
    await repo.archive(spare.id, expectedRevision: spare.revision);
    await repo.deleteRoom((await repo.getRoom(spare.id))!);
    check(await repo.getRoom(spare.id) == null, 'room deleted');
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
