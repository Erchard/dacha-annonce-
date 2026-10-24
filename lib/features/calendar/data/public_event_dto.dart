import '../../bookings/domain/event_details.dart';
import '../../bookings/data/booking_dto.dart';

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
    'contactPhone',
    'notes',
    'directions',
    'coverImageBytes',
    'coverImageContentType',
    'coverImageFileName',
    'startAt',
    'endAt',
    'timeZone',
    'bookingVersion',
    'publishedAt',
    'updatedAt',
    'schemaVersion',
  };
  static PublicEvent decode(String id, Map<String, dynamic> data) {
    final f = Fields({
      'contactPhone': '',
      'notes': '',
      'directions': <String>[],
      'coverImageBytes': null,
      'coverImageContentType': null,
      'coverImageFileName': null,
      ...data,
    }, keys);
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
      contactPhone: f.value('contactPhone'),
      notes: f.value('notes'),
      directions: checkedDirections(f.value<List<dynamic>>('directions')),
      coverImage: BookingDto.coverFrom(f.data),
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
    'contactPhone': event.contactPhone,
    'notes': event.notes,
    'directions': event.directions,
    ...BookingDto.coverFields(event.coverImage),
    'startAt': Timestamp.fromDate(event.interval.start),
    'endAt': Timestamp.fromDate(event.interval.end),
    'timeZone': 'Europe/Kyiv',
    'bookingVersion': event.bookingVersion,
    'publishedAt': Timestamp.fromDate(event.publishedAt),
    'updatedAt': Timestamp.fromDate(event.updatedAt),
    'schemaVersion': 1,
  };
}
