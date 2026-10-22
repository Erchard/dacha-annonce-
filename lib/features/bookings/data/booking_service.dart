import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';
import '../../auth/data/user_profile_dto.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/booking.dart';
import 'booking_dto.dart';

/// All booking writes use this transaction. No writes or UI effects occur elsewhere.
class BookingService {
  const BookingService(this.db, this.auth, {this.clock = const SystemClock()});
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final Clock clock;
  String newId() => db.collection('bookings').doc().id;

  static String? seriesPrefix(String id) =>
      RegExp(r'^[A-Za-z0-9]{20}-[0-9]{8}$').hasMatch(id)
      ? id.substring(0, 21)
      : null;

  Future<List<Booking>> seriesOccurrences(String id) => firestoreCall(() async {
    final prefix = seriesPrefix(id);
    if (prefix == null) throw const DomainException(ErrorCode.validation);
    final user = auth.currentUser;
    if (user == null) throw const DomainException(ErrorCode.unauthenticated);
    final profile = (await db.collection('users').doc(user.uid).get()).data();
    if (profile == null || profile['isDisabled'] != false) {
      throw const DomainException(ErrorCode.permissionDenied);
    }
    Query<Map<String, dynamic>> query = db.collection('bookings');
    if (profile['role'] != 'admin') {
      query = query.where('organizerId', isEqualTo: user.uid);
    }
    final result = await query
        .orderBy(FieldPath.documentId)
        .startAt([prefix])
        .endAt(['$prefix\uf8ff'])
        .limit(27)
        .get();
    if (result.docs.length > 26) {
      throw const DomainException(ErrorCode.validation);
    }
    return result.docs
        .map((d) => BookingDto.decode(d.id, d.data()))
        .where((b) => b.status != BookingStatus.deleted)
        .toList();
  });

  Future<void> execute(
    String id,
    BookingAction action, {
    required int expectedVersion,
    BookingDraft? draft,
    String? reason,
  }) => firestoreCall(() async {
    final user = auth.currentUser;
    if (user == null) throw const DomainException(ErrorCode.unauthenticated);
    final creating =
        action == BookingAction.createPending ||
        action == BookingAction.createApproved;
    if (creating && (draft == null || expectedVersion != 0)) {
      throw const DomainException(ErrorCode.validation);
    }
    if (action == BookingAction.reject) {
      checkedText(reason?.trim() ?? '', 'rejectionReason', 3, 1000);
    }
    if (reason != null) checkedText(reason.trim(), 'reason', 0, 1000);
    await firestoreTransaction(db, (tx) async {
      final ref = db.collection('bookings').doc(id);
      final snapshot = await tx.get(ref);
      final before = snapshot.data();
      final booking = before == null ? null : BookingDto.decode(id, before);
      if (!creating && booking == null) {
        throw const DomainException(ErrorCode.notFound);
      }
      if ((booking?.version ?? 0) != expectedVersion) {
        throw const DomainException(ErrorCode.staleVersion);
      }
      final profileData = (await tx.get(db.collection('users').doc(user.uid)))
          .data();
      if (profileData == null) {
        throw const DomainException(ErrorCode.notFound, field: 'profile');
      }
      final profile = UserProfileDto.decode(user.uid, profileData);
      if (profile.isDisabled) {
        throw const DomainException(ErrorCode.accountDisabled);
      }
      final admin = profile.role == UserRole.admin;
      final owner =
          profile.role == UserRole.organizer &&
          (creating || booking!.organizerId == user.uid);
      final publisher = owner && profile.canPublish;
      if (!admin && !owner) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      if (action != BookingAction.delete &&
          booking != null &&
          ![
            BookingStatus.pending,
            BookingStatus.approved,
          ].contains(booking.status)) {
        throw const DomainException(ErrorCode.validation, field: 'status');
      }
      final selected = draft ?? booking?.draft;
      if (selected == null) throw const DomainException(ErrorCode.validation);
      switch (action) {
        case BookingAction.delete:
          if ((!admin && !publisher) ||
              booking!.status == BookingStatus.deleted) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
        case BookingAction.createPending:
          if (!admin && !user.emailVerified) {
            throw const DomainException(ErrorCode.emailNotVerified);
          }
          selected.interval.validateFuture(clock);
        case BookingAction.createApproved:
          if (!admin && !publisher) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
          selected.interval.validateFuture(clock);
        case BookingAction.approve:
        case BookingAction.reject:
          if (!admin || booking!.status != BookingStatus.pending) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
          if (action == BookingAction.approve) {
            selected.interval.validateFuture(clock);
          }
        case BookingAction.edit:
          if (draft == null) throw const DomainException(ErrorCode.validation);
          if (booking!.status == BookingStatus.pending) {
            if (!admin && !user.emailVerified) {
              throw const DomainException(ErrorCode.emailNotVerified);
            }
            selected.interval.validateFuture(clock);
          } else if ((!admin && !publisher) ||
              selected.roomId != booking.draft.roomId ||
              selected.interval.start != booking.draft.interval.start ||
              selected.interval.end != booking.draft.interval.end) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
        case BookingAction.reschedule:
          if ((!admin && !publisher) ||
              booking!.status != BookingStatus.approved ||
              !booking.draft.interval.start.isAfter(clock.now()) ||
              draft == null) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
          selected.interval.validateFuture(clock);
        case BookingAction.cancel:
          if (!admin && !booking!.draft.interval.start.isAfter(clock.now())) {
            throw const DomainException(ErrorCode.permissionDenied);
          }
      }
      final now = FieldValue.serverTimestamp();
      final next = <String, dynamic>{
        if (before != null)
          ...before
        else ...{
          'organizerId': user.uid,
          'timeZone': 'Europe/Kyiv',
          'status': 'pending',
          'roomNameSnapshot': '',
          'locationSnapshot': '',
          'rejectionReason': null,
          'cancellationReason': null,
          'reviewedAt': null,
          'reviewedBy': null,
          'cancelledAt': null,
          'cancelledBy': null,
          'createdAt': now,
          'createdBy': user.uid,
          'schemaVersion': 1,
        },
        if (creating ||
            action == BookingAction.edit ||
            action == BookingAction.reschedule) ...{
          'roomId': selected.roomId,
          'title': selected.title,
          'description': selected.description,
          'responsibleName': selected.responsibleName,
          'contactPhone': selected.contactPhone,
          'notes': selected.notes,
          'directions': selected.directions,
          'startAt': Timestamp.fromDate(selected.interval.start),
          'endAt': Timestamp.fromDate(selected.interval.end),
        },
        'version': expectedVersion + 1,
        'lastAction': creating ? 'create' : action.name,
        'updatedAt': now,
        'updatedBy': user.uid,
      };
      if (action == BookingAction.createApproved ||
          action == BookingAction.approve) {
        next['status'] = 'approved';
      }
      if (action == BookingAction.reject) {
        next['status'] = 'rejected';
        next['rejectionReason'] = reason!.trim();
      }
      if (action == BookingAction.delete) next['status'] = 'deleted';
      if (action == BookingAction.cancel) {
        next.addAll({
          'status': 'cancelled',
          'cancelledAt': now,
          'cancelledBy': user.uid,
          'cancellationReason': reason?.trim(),
        });
      }
      if ([
        BookingAction.createApproved,
        BookingAction.approve,
        BookingAction.reject,
      ].contains(action)) {
        next.addAll({'reviewedAt': now, 'reviewedBy': user.uid});
      }
      next['occupancyBlockIds'] = selected.interval.blockIds;
      final requiresRoom =
          creating ||
          action == BookingAction.approve ||
          action == BookingAction.reschedule ||
          action == BookingAction.edit &&
              booking!.status == BookingStatus.pending;
      if (requiresRoom) {
        final room = (await tx.get(db.collection('rooms').doc(selected.roomId)))
            .data();
        if (room == null) {
          throw const DomainException(ErrorCode.notFound, field: 'room');
        }
        if (room['isActive'] != true) {
          throw const DomainException(ErrorCode.validation, field: 'room');
        }
        if (next['status'] == 'approved') {
          next.addAll({
            'roomNameSnapshot': room['name'],
            'locationSnapshot': room['locationLabel'],
          });
        }
      }
      final old = booking?.status == BookingStatus.approved
          ? _paths(booking!.draft)
          : <String, Set<String>>{};
      final wanted = next['status'] == 'approved'
          ? _paths(selected)
          : <String, Set<String>>{};
      final paths = {...old.keys, ...wanted.keys};
      final locks = <String, Map<String, dynamic>?>{};
      for (final path in paths) {
        locks[path] = (await tx.get(db.doc(path))).data();
      }
      final publicRef = db.collection('publicEvents').doc(id);
      final previousPublic = booking?.status == BookingStatus.approved
          ? (await tx.get(publicRef)).data()
          : null;
      if (booking?.status == BookingStatus.approved && previousPublic == null) {
        throw const DomainException(
          ErrorCode.unexpected,
          technicalCode: 'missing-public-projection',
        );
      }
      final writes = <String, Map<String, dynamic>>{};
      for (final path in paths) {
        final existing = locks[path];
        final slots = existing == null
            ? <String, dynamic>{
                for (var i = 0; i < 12; i++)
                  's${i.toString().padLeft(2, '0')}': '',
              }
            : Map<String, dynamic>.from(existing['slots'] as Map);
        if (slots.length != 12 ||
            List.generate(
              12,
              (i) => 's${i.toString().padLeft(2, '0')}',
            ).any((k) => slots[k] is! String)) {
          throw const DomainException(
            ErrorCode.unexpected,
            technicalCode: 'invalid-occupancy',
          );
        }
        for (final key in old[path] ?? <String>{}) {
          if (slots[key] != id) {
            throw const DomainException(
              ErrorCode.unexpected,
              technicalCode: 'occupancy-owner-mismatch',
            );
          }
          slots[key] = '';
        }
        for (final key in wanted[path] ?? <String>{}) {
          if (slots[key] != '' && slots[key] != id) {
            throw const DomainException(ErrorCode.bookingConflict);
          }
          slots[key] = id;
        }
        writes[path] = {
          'blockStartAt': Timestamp.fromMillisecondsSinceEpoch(
            int.parse(path.split('/').last) * 1000,
          ),
          'slots': slots,
          'lastMutationBookingId': id,
          'lastMutationVersion': expectedVersion + 1,
          'updatedAt': now,
          'updatedBy': user.uid,
          'schemaVersion': 1,
        };
      }
      // All reads are complete before the first write.
      for (final entry in writes.entries) {
        tx.set(db.doc(entry.key), entry.value);
      }
      tx.set(ref, next);
      tx.set(ref.collection('history').doc('${expectedVersion + 1}'), {
        'version': expectedVersion + 1,
        'action': next['lastAction'],
        'actorId': user.uid,
        'actorRole': profile.role.name,
        'at': now,
        'fromStatus': before?['status'],
        'toStatus': next['status'],
        'oldRoomId': before?['roomId'],
        'newRoomId': next['roomId'],
        'oldStartAt': before?['startAt'],
        'oldEndAt': before?['endAt'],
        'newStartAt': next['startAt'],
        'newEndAt': next['endAt'],
      });
      if (next['status'] == 'approved') {
        tx.set(publicRef, {
          for (final key in [
            'title',
            'description',
            'roomId',
            'roomNameSnapshot',
            'locationSnapshot',
            'responsibleName',
            'startAt',
            'endAt',
            'timeZone',
          ])
            key: next[key],
          'contactPhone': next['contactPhone'] ?? '',
          'notes': next['notes'] ?? '',
          'directions': next['directions'] ?? <String>[],
          'bookingVersion': expectedVersion + 1,
          'publishedAt': previousPublic == null
              ? now
              : previousPublic['publishedAt'],
          'updatedAt': now,
          'schemaVersion': 1,
        });
      } else if (previousPublic != null) {
        tx.delete(publicRef);
      }
    });
  });

  Map<String, Set<String>> _paths(BookingDraft draft) =>
      draft.interval.slotsByBlock.map(
        (block, slots) =>
            MapEntry('rooms/${draft.roomId}/occupancy/$block', slots),
      );
}
