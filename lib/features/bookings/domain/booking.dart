import 'event_details.dart';
import '../../../core/time/time_zone_service.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';

enum BookingStatus { pending, approved, rejected, cancelled, deleted }

enum BookingAction {
  createPending,
  createApproved,
  edit,
  approve,
  reject,
  cancel,
  reschedule,
  delete,
}

class BookingDraft {
  BookingDraft({
    required this.roomId,
    required String title,
    required String description,
    String responsibleName = '',
    String contactPhone = '',
    String notes = '',
    List<String> directions = const [],
    required this.interval,
  }) : contactPhone = checkedContactPhone(contactPhone),
       notes = checkedText(notes.trim(), 'notes', 0, 500),
       directions = checkedDirections(directions),
       title = checkedText(title.trim(), 'title', 3, 120),
       description = checkedText(description.trim(), 'description', 0, 5000),
       responsibleName = checkedText(
         responsibleName.trim(),
         'responsibleName',
         0,
         80,
       ) {
    if (roomId.isEmpty || roomId.contains('/')) {
      throw const DomainException(ErrorCode.validation, field: 'roomId');
    }
  }
  final String roomId, title, description, responsibleName, contactPhone, notes;
  final List<String> directions;
  final BookingInterval interval;
}

class Booking {
  const Booking({
    required this.id,
    required this.organizerId,
    required this.draft,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.rejectionReason,
    required this.cancellationReason,
    required this.roomNameSnapshot,
  });
  final String id, organizerId, roomNameSnapshot;
  final BookingDraft draft;
  final BookingStatus status;
  final int version;
  final DateTime createdAt;
  final String? rejectionReason, cancellationReason;
}

/// A past day never blocks room removal; today's events still do.
bool bookingPreventsRoomDeletion(
  BookingStatus status,
  DateTime start,
  DateTime now,
) {
  if (status != BookingStatus.pending && status != BookingStatus.approved)
    return false;
  final zone = TimeZoneService();
  final today = zone.toKyiv(now), day = zone.toKyiv(start);
  return !DateTime(
    day.year,
    day.month,
    day.day,
  ).isBefore(DateTime(today.year, today.month, today.day));
}
