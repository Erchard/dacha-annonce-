import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/data/firestore_fields.dart';
import '../../core/domain/page.dart';
import '../../core/errors/domain_exception.dart';
import '../../features/auth/data/user_profile_dto.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/rooms/data/room_dto.dart';
import '../../features/rooms/domain/room.dart';
import '../../features/rooms/domain/room_repository.dart';
import '../../features/calendar/data/public_event_dto.dart';
import '../../features/calendar/domain/public_event.dart';
import '../../features/calendar/domain/public_event_repository.dart';
import '../../features/bookings/data/booking_dto.dart';
import '../../features/bookings/domain/booking.dart';

/// Small Firebase adapters share pagination and audited writes, not a CRUD framework.
class AppRepository
    implements RoomRepository, UserRepository, PublicEventRepository {
  const AppRepository(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String newRoomId() => db.collection('rooms').doc().id;
  String get uid =>
      auth.currentUser?.uid ??
      (throw const DomainException(ErrorCode.unauthenticated));

  Query<Map<String, dynamic>> _cursor(
    Query<Map<String, dynamic>> query,
    PageRequest page,
    String key,
  ) {
    final cursor = page.after;
    if (cursor != null) {
      if (cursor.queryKey != key) {
        throw const DomainException(ErrorCode.validation, field: 'cursor');
      }
      final value = cursor.value is DateTime
          ? Timestamp.fromDate(cursor.value as DateTime)
          : cursor.value;
      query = query.startAfter([value, cursor.id]);
    }
    return query.limit(page.limit);
  }

  Page<T> _page<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    PageRequest request,
    String key,
    String order,
    T Function(String, Map<String, dynamic>) decode,
  ) {
    final docs = snapshot.docs;
    PageCursor? next;
    if (docs.length == request.limit) {
      final raw = docs.last.data()[order];
      if (raw == null) {
        throw const DomainException(ErrorCode.validation, field: 'cursor');
      }
      next = PageCursor(
        queryKey: key,
        value: raw is Timestamp ? raw.toDate().toUtc() : raw,
        id: docs.last.id,
      );
    }
    return Page(docs.map((d) => decode(d.id, d.data())), next);
  }

  Stream<T> _stream<T>(Stream<T> source) async* {
    try {
      yield* source;
    } on FirebaseException catch (error) {
      throw firebaseFailure(error);
    }
  }

  @override
  Stream<Page<Room>> watchActiveRooms(PageRequest page) {
    const key = 'active-rooms';
    return _stream(
      _cursor(
        db
            .collection('rooms')
            .where('isActive', isEqualTo: true)
            .orderBy('sortOrder')
            .orderBy(FieldPath.documentId),
        page,
        key,
      ).snapshots().map(
        (s) => _page(s, page, key, 'sortOrder', RoomDto.decode),
      ),
    );
  }

  Future<Page<Room>> listRooms(PageRequest page, {bool activeOnly = true}) =>
      firestoreCall(() async {
        final key = activeOnly ? 'active-rooms' : 'all-rooms';
        Query<Map<String, dynamic>> query = db.collection('rooms');
        if (activeOnly) query = query.where('isActive', isEqualTo: true);
        final result = await _cursor(
          query.orderBy('sortOrder').orderBy(FieldPath.documentId),
          page,
          key,
        ).get();
        return _page(result, page, key, 'sortOrder', RoomDto.decode);
      });
  @override
  Future<Room?> getRoom(String id) => firestoreCall(() async {
    final s = await db.collection('rooms').doc(id).get();
    return s.data() == null ? null : RoomDto.decode(id, s.data()!);
  });
  @override
  Future<Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    PageRequest page, {
    String? roomId,
  }) => firestoreCall(() async {
    if (!start.isBefore(end) ||
        end.difference(start) > const Duration(days: 62)) {
      throw const DomainException(ErrorCode.validation, field: 'range');
    }
    final from = start.toUtc(), to = end.toUtc();
    final key = 'events:$from:$to:$roomId';
    Query<Map<String, dynamic>> query = db.collection('publicEvents');
    if (roomId != null) query = query.where('roomId', isEqualTo: roomId);
    final result = await _cursor(
      query
          .where(
            'startAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              from.subtract(const Duration(hours: 6)),
            ),
          )
          .where('startAt', isLessThan: Timestamp.fromDate(to))
          .orderBy('startAt')
          .orderBy(FieldPath.documentId),
      page,
      key,
    ).get();
    final loaded = _page(result, page, key, 'startAt', PublicEventDto.decode);
    return Page(
      loaded.items.where((event) => event.interval.end.isAfter(from)),
      loaded.next,
    );
  });
  @override
  Future<PublicEvent?> getPublishedEvent(String id) => firestoreCall(() async {
    final s = await db.collection('publicEvents').doc(id).get();
    return s.data() == null ? null : PublicEventDto.decode(id, s.data()!);
  });
  @override
  Stream<UserProfile?> watchMyProfile() => _stream(
    db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (s) =>
              s.data() == null ? null : UserProfileDto.decode(s.id, s.data()!),
        ),
  );
  @override
  Future<void> updateMyDisplayName(String displayName) =>
      firestoreCall(() async {
        final name = checkedText(displayName.trim(), 'displayName', 2, 80);
        await db.collection('users').doc(uid).update({
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
        });
      });
  @override
  Future<Page<UserProfile>> listProfiles(
    PageRequest page, {
    required UserRole role,
  }) => firestoreCall(() async {
    final key = 'users:${role.name}';
    final result = await _cursor(
      db
          .collection('users')
          .where('role', isEqualTo: role.name)
          .orderBy('displayName')
          .orderBy(FieldPath.documentId),
      page,
      key,
    ).get();
    return _page(result, page, key, 'displayName', UserProfileDto.decode);
  });
  Future<Booking?> getBooking(String id) => firestoreCall(() async {
    final s = await db.collection('bookings').doc(id).get();
    return s.data() == null ? null : BookingDto.decode(id, s.data()!);
  });
  Future<Page<Booking>> listBookings(
    PageRequest page, {
    bool forAdmin = false,
    BookingStatus? status,
  }) => firestoreCall(() async {
    final owner = forAdmin ? null : uid;
    final key = 'bookings:$owner:${status?.name}';
    Query<Map<String, dynamic>> query = db.collection('bookings');
    if (owner != null) query = query.where('organizerId', isEqualTo: owner);
    if (status != null) query = query.where('status', isEqualTo: status.name);
    final result = await _cursor(
      query
          .orderBy('createdAt', descending: !forAdmin)
          .orderBy(FieldPath.documentId, descending: !forAdmin),
      page,
      key,
    ).get();
    return _page(result, page, key, 'createdAt', BookingDto.decode);
  });

  Map<String, dynamic> _roomView(Map<String, dynamic> d) => {
    for (final key in [
      'name',
      'description',
      'locationLabel',
      'capacity',
      'isActive',
      'sortOrder',
    ])
      key: d[key],
  };
  @override
  Future<void> upsert(Room room, {required int expectedRevision}) =>
      firestoreCall(() async {
        final actor = uid;
        final audit = db.collection('adminAudit').doc();
        final ref = db.collection('rooms').doc(room.id);
        await firestoreTransaction(db, (tx) async {
          final old = (await tx.get(ref)).data();
          if ((old?['revision'] ?? 0) != expectedRevision) {
            throw const DomainException(ErrorCode.staleVersion);
          }
          final now = FieldValue.serverTimestamp();
          final next = RoomDto.encode(room)
            ..addAll({
              'revision': expectedRevision + 1,
              'lastAuditId': audit.id,
              'createdAt': old == null ? now : old['createdAt'],
              'updatedAt': now,
            });
          final before = old == null ? <String, dynamic>{} : _roomView(old),
              after = _roomView(next);
          tx.set(ref, next);
          tx.set(audit, {
            'entityType': 'room',
            'entityId': room.id,
            'action': old == null
                ? 'create'
                : old['isActive'] == true && !room.isActive
                ? 'archive'
                : 'update',
            'actorId': actor,
            'at': now,
            'revision': expectedRevision + 1,
            'before': before,
            'after': after,
            'changedFields': after.keys
                .where(
                  (key) =>
                      !before.containsKey(key) || before[key] != after[key],
                )
                .toList(),
          });
        });
      });
  @override
  Future<void> archive(String id, {required int expectedRevision}) async {
    final room = await getRoom(id);
    if (room == null) throw const DomainException(ErrorCode.notFound);
    await upsert(
      Room(
        id: id,
        name: room.name,
        description: room.description,
        locationLabel: room.locationLabel,
        capacity: room.capacity,
        isActive: false,
        sortOrder: room.sortOrder,
        createdAt: room.createdAt,
        updatedAt: room.updatedAt,
        revision: room.revision,
        lastAuditId: room.lastAuditId,
      ),
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<void> setDisabled(
    String id,
    bool disabled, {
    required int expectedRevision,
  }) => firestoreCall(() async {
    final actor = uid;
    final ref = db.collection('users').doc(id);
    final audit = db.collection('adminAudit').doc();
    await firestoreTransaction(db, (tx) async {
      final before = (await tx.get(ref)).data();
      if (before == null) throw const DomainException(ErrorCode.notFound);
      if (before['adminRevision'] != expectedRevision) {
        throw const DomainException(ErrorCode.staleVersion);
      }
      if (before['role'] != 'organizer') {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      if (before['isDisabled'] == disabled) {
        throw const DomainException(ErrorCode.validation, field: 'isDisabled');
      }
      final now = FieldValue.serverTimestamp();
      tx.update(ref, {
        'isDisabled': disabled,
        'adminRevision': expectedRevision + 1,
        'lastAdminAuditId': audit.id,
        'updatedAt': now,
        'updatedBy': actor,
      });
      tx.set(audit, {
        'entityType': 'user',
        'entityId': id,
        'action': 'set_disabled',
        'actorId': actor,
        'at': now,
        'revision': expectedRevision + 1,
        'before': {'isDisabled': before['isDisabled']},
        'after': {'isDisabled': disabled},
        'changedFields': ['isDisabled'],
      });
    });
  });
}

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this.auth, this.db);
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  @override
  Stream<AuthSession?> get session => auth.userChanges().map(
    (u) =>
        u == null ? null : AuthSession(u.uid, emailVerified: u.emailVerified),
  );
  Future<void> recoverProfile(String displayName) async {
    final user = auth.currentUser;
    if (user == null) throw const DomainException(ErrorCode.unauthenticated);
    final name = checkedText(displayName.trim(), 'displayName', 2, 80);
    final ref = db.collection('users').doc(user.uid);
    await firestoreCall(
      () => firestoreTransaction(db, (tx) async {
        if ((await tx.get(ref)).exists) {
          throw const DomainException(ErrorCode.staleVersion);
        }
        final now = FieldValue.serverTimestamp();
        tx.set(ref, {
          'displayName': name,
          'role': 'organizer',
          'isDisabled': false,
          'createdAt': now,
          'updatedAt': now,
          'createdBy': user.uid,
          'updatedBy': user.uid,
          'schemaVersion': 1,
          'adminRevision': 0,
          'lastAdminAuditId': null,
        });
      }),
    );
  }

  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    checkedText(displayName.trim(), 'displayName', 2, 80);
    await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await recoverProfile(displayName);
    await sendVerification();
  }

  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => auth.signOut();
  static ActionCodeSettings get _mailReturn => ActionCodeSettings(
    url: 'https://dacha-annonce.web.app/login',
    handleCodeInApp: false,
  );

  @override
  Future<void> sendVerification() async {
    final user = auth.currentUser;
    if (user == null) throw const DomainException(ErrorCode.unauthenticated);
    await user.sendEmailVerification(_mailReturn);
  }

  @override
  Future<void> resetPassword(String email) => auth.sendPasswordResetEmail(
    email: email.trim(),
    actionCodeSettings: _mailReturn,
  );
  @override
  Future<void> reloadUser() async {
    await auth.currentUser?.reload();
    await auth.currentUser?.getIdToken(true);
  }
}
