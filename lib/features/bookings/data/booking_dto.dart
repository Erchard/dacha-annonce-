import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/domain/event_details.dart';
import '../../../core/data/firestore_fields.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';
import '../domain/booking.dart';

class BookingDto {
  static const keys = {
    'organizerId',
    'roomId',
    'title',
    'description',
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
    'status',
    'roomNameSnapshot',
    'locationSnapshot',
    'rejectionReason',
    'cancellationReason',
    'reviewedAt',
    'reviewedBy',
    'cancelledAt',
    'cancelledBy',
    'occupancyBlockIds',
    'version',
    'lastAction',
    'createdAt',
    'updatedAt',
    'createdBy',
    'updatedBy',
    'schemaVersion',
  };

  static CoverImage? coverFrom(Map<String, dynamic> data) {
    final raw = data['coverImageBytes'];
    return CoverImage.optional(
      bytes: raw is Blob ? raw.bytes : raw,
      contentType: data['coverImageContentType'],
      fileName: data['coverImageFileName'],
    );
  }

  static Map<String, dynamic> coverFields(CoverImage? cover) => {
    'coverImageBytes': cover == null ? null : Blob(cover.bytes),
    'coverImageContentType': cover?.contentType,
    'coverImageFileName': cover?.fileName,
  };

  static Booking decode(String id, Map<String, dynamic> data) {
    final f = Fields({
      'contactPhone': '',
      'notes': '',
      'directions': <String>[],
      'coverImageBytes': null,
      'coverImageContentType': null,
      'coverImageFileName': null,
      ...data,
    }, keys);
    if (f.value<String>('timeZone') != 'Europe/Kyiv' ||
        f.value<int>('version') < 1) {
      throw const DomainException(ErrorCode.validation, field: 'booking');
    }
    final interval = BookingInterval(f.time('startAt'), f.time('endAt'));
    final blockIds = f.value<List<dynamic>>('occupancyBlockIds');
    if (blockIds.any((v) => v is! String) ||
        blockIds.join(',') != interval.blockIds.join(',')) {
      throw const DomainException(
        ErrorCode.validation,
        field: 'occupancyBlockIds',
      );
    }
    return Booking(
      id: id,
      roomNameSnapshot: f.value<String>('roomNameSnapshot'),
      organizerId: f.value('organizerId'),
      draft: BookingDraft(
        roomId: f.value('roomId'),
        title: f.value('title'),
        description: f.value('description'),
        responsibleName: f.value('responsibleName'),
        contactPhone: f.value('contactPhone'),
        notes: f.value('notes'),
        directions: checkedDirections(f.value<List<dynamic>>('directions')),
        coverImage: coverFrom(f.data),
        interval: interval,
      ),
      status: f.enumeration('status', BookingStatus.values),
      version: f.value('version'),
      createdAt: f.time('createdAt'),
      rejectionReason: f.value<String?>('rejectionReason'),
      cancellationReason: f.value<String?>('cancellationReason'),
    );
  }
}
