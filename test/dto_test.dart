import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dacha_annonce/core/errors/domain_exception.dart';
import 'package:dacha_annonce/core/domain/page.dart';
import 'package:dacha_annonce/features/rooms/data/room_dto.dart';
import 'package:dacha_annonce/features/auth/data/user_profile_dto.dart';
import 'package:dacha_annonce/features/calendar/data/public_event_dto.dart';

void main() {
  final now = Timestamp.fromDate(DateTime.utc(2026, 10, 5));
  final room = <String, dynamic>{
    'name': 'Зала',
    'description': '',
    'locationLabel': 'Дача',
    'capacity': 20,
    'isActive': true,
    'sortOrder': 0,
    'createdAt': now,
    'updatedAt': now,
    'schemaVersion': 1,
    'revision': 1,
    'lastAuditId': 'audit-id',
  };
  final profile = <String, dynamic>{
    'displayName': 'Організатор',
    'role': 'organizer',
    'isDisabled': false,
    'createdAt': now,
    'updatedAt': now,
    'createdBy': 'uid',
    'updatedBy': 'uid',
    'schemaVersion': 1,
    'adminRevision': 0,
    'lastAdminAuditId': null,
  };
  final event = <String, dynamic>{
    'title': 'Зустріч громади',
    'description': 'Опис',
    'roomId': 'room',
    'roomNameSnapshot': 'Зала',
    'locationSnapshot': 'Дача',
    'responsibleName': 'Марія',
    'startAt': now,
    'endAt': Timestamp.fromDate(DateTime.utc(2026, 10, 5, 1)),
    'timeZone': 'Europe/Kyiv',
    'bookingVersion': 1,
    'publishedAt': now,
    'updatedAt': now,
    'schemaVersion': 1,
  };
  test('DTO round trips preserve types and UTC timestamps', () {
    expect(RoomDto.encode(RoomDto.decode('room', room)), room);
    expect(
      UserProfileDto.encode(UserProfileDto.decode('uid', profile)),
      profile,
    );
    expect(PublicEventDto.encode(PublicEventDto.decode('event', event)), event);
    expect(RoomDto.decode('room', room).createdAt.isUtc, isTrue);
  });
  test('unknown roles, types, schema versions and fields fail explicitly', () {
    for (final patch in [
      {'role': 'superadmin'},
      {'isDisabled': 'false'},
      {'schemaVersion': 2},
      {'schemaVersion': 1.0},
      {'email': 'private@example.invalid'},
    ]) {
      expect(
        () => UserProfileDto.decode('uid', {...profile, ...patch}),
        throwsA(isA<DomainException>()),
      );
    }
    final missing = {...room}..remove('capacity');
    expect(
      () => RoomDto.decode('room', missing),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => RoomDto.decode('room', {...room, 'capacity': -1}),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => PublicEventDto.decode('event', {...event, 'organizerId': 'uid'}),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => PublicEventDto.decode('event', {...event, 'timeZone': 'UTC'}),
      throwsA(isA<DomainException>()),
    );
  });
  test('timestamp precision is never silently truncated', () {
    expect(
      () => PublicEventDto.decode('event', {
        ...event,
        'startAt': Timestamp(now.seconds, 1),
      }),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => PublicEventDto.decode('event', {
        ...event,
        'startAt': Timestamp(now.seconds, 1000),
      }),
      throwsA(isA<DomainException>()),
    );
  });
  test('list limits are bounded by the query contract', () {
    expect(PageRequest().limit, 25);
    for (final limit in [0, -1, 101]) {
      expect(() => PageRequest(limit: limit), throwsA(isA<DomainException>()));
    }
    expect(PageRequest(limit: 100).limit, 100);
  });
}
