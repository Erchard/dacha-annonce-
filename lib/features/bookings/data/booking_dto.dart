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
    'participationCondition',
    'announcementStatus',
    'eventDirection',
    'eventFormat',
    'targetAudiences',
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

  static Map<String, dynamic> structuredFields(BookingDraft draft) => {
    'participationCondition': draft.participationCondition,
    'announcementStatus': draft.announcementStatus,
    'eventDirection': draft.eventDirection,
    'eventFormat': draft.eventFormat,
    'targetAudiences': draft.targetAudiences,
  };

  static BookingDraft draftFrom(Map<String, dynamic> data, Fields f) {
    final hasStructured = data.containsKey('eventDirection');
    final legacy = checkedDirections(
      f.value<List<dynamic>>('directions'),
    );
    return BookingDraft(
      roomId: f.value('roomId'),
      title: f.value('title'),
      description: f.value('description'),
      responsibleName: f.value('responsibleName'),
      contactPhone: f.value('contactPhone'),
      notes: f.value('notes'),
      legacyDirections: hasStructured ? const [] : legacy,
      participationCondition: f.value('participationCondition'),
      announcementStatus: f.value('announcementStatus'),
      eventDirection: f.value('eventDirection'),
      eventFormat: f.value('eventFormat'),
      targetAudiences: List<String>.from(
        f.value<List<dynamic>>('targetAudiences'),
      ),
      coverImage: coverFrom(f.data),
      interval: BookingInterval(f.time('startAt'), f.time('endAt')),
    );
  }

  static Map<String, dynamic> _merged(Map<String, dynamic> data) => {
    for (final key in keys) key: null,
    'contactPhone': '',
    'notes': '',
    'directions': <String>[],
    'participationCondition': participationConditionOptions.first,
    'announcementStatus': 'planned',
    'eventDirection': eventDirectionOptions.first,
    'eventFormat': eventFormatOptions.first,
    'targetAudiences': <String>[allWelcomeAudience],
    'responsibleName': '',
    'roomNameSnapshot': '',
    'locationSnapshot': '',
    for (final entry in data.entries)
      if (keys.contains(entry.key)) entry.key: entry.value,
  };

  static Booking decode(String id, Map<String, dynamic> data) {
    final f = Fields(_merged(data), keys);
    if (f.value<String>('timeZone') != 'Europe/Kyiv' ||
        f.value<int>('version') < 1) {
      throw const DomainException(ErrorCode.validation, field: 'booking');
    }
    final draft = draftFrom(data, f);
    final blockIds = f.value<List<dynamic>>('occupancyBlockIds');
    if (blockIds.any((v) => v is! String) ||
        blockIds.join(',') != draft.interval.blockIds.join(',')) {
      throw const DomainException(
        ErrorCode.validation,
        field: 'occupancyBlockIds',
      );
    }
    return Booking(
      id: id,
      roomNameSnapshot: f.value<String>('roomNameSnapshot'),
      organizerId: f.value('organizerId'),
      draft: draft,
      status: f.enumeration('status', BookingStatus.values),
      version: f.value('version'),
      createdAt: f.time('createdAt'),
      rejectionReason: f.value<String?>('rejectionReason'),
      cancellationReason: f.value<String?>('cancellationReason'),
    );
  }
}
