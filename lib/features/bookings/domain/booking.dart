import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';

enum BookingStatus { pending, approved, rejected, cancelled }

enum BookingAction {
  createPending,
  createApproved,
  edit,
  approve,
  reject,
  cancel,
  reschedule,
}

class BookingDraft {
  BookingDraft({
    required this.roomId,
    required String title,
    required String description,
    String responsibleName = '',
    required this.interval,
  }) : title = checkedText(title.trim(), 'title', 3, 120),
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
  final String roomId, title, description, responsibleName;
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
