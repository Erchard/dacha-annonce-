import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';
import '../domain/public_event.dart';

class PublicEventDto {
  static const keys = {
    'title',
    'description',
    'roomId',
    'roomNameSnapshot',
    'locationSnapshot',
    'responsibleName',
    'startAt',
    'endAt',
    'timeZone',
    'bookingVersion',
    'publishedAt',
    'updatedAt',
    'schemaVersion',
  };
  static PublicEvent decode(String id, Map<String, dynamic> data) {
    final f = Fields(data, keys);
    if (f.value<String>('timeZone') != 'Europe/Kyiv') {
      throw const DomainException(ErrorCode.validation, field: 'timeZone');
    }
    return PublicEvent(
      id: id,
      title: f.value('title'),
      description: f.value('description'),
      roomId: f.value('roomId'),
      roomNameSnapshot: f.value('roomNameSnapshot'),
      locationSnapshot: f.value('locationSnapshot'),
      responsibleName: f.value('responsibleName'),
      interval: BookingInterval(f.time('startAt'), f.time('endAt')),
      bookingVersion: f.value('bookingVersion'),
      publishedAt: f.time('publishedAt'),
      updatedAt: f.time('updatedAt'),
    );
  }

  static Map<String, dynamic> encode(PublicEvent event) => {
    'title': event.title,
    'description': event.description,
    'roomId': event.roomId,
    'roomNameSnapshot': event.roomNameSnapshot,
    'locationSnapshot': event.locationSnapshot,
    'responsibleName': event.responsibleName,
    'startAt': Timestamp.fromDate(event.interval.start),
    'endAt': Timestamp.fromDate(event.interval.end),
    'timeZone': 'Europe/Kyiv',
    'bookingVersion': event.bookingVersion,
    'publishedAt': Timestamp.fromDate(event.publishedAt),
    'updatedAt': Timestamp.fromDate(event.updatedAt),
    'schemaVersion': 1,
  };
}
