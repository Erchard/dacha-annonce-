import '../../bookings/domain/event_details.dart';
import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';

class PublicEvent {
  PublicEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.roomId,
    required this.roomNameSnapshot,
    required this.locationSnapshot,
    required this.responsibleName,
    required this.interval,
    String contactPhone = '',
    String notes = '',
    List<String> legacyDirections = const [],
    required String participationCondition,
    String announcementStatus = 'planned',
    required String eventDirection,
    required String eventFormat,
    List<String> targetAudiences = const [allWelcomeAudience],
    this.hasStructuredFields = true,
    this.coverImage,
    required this.bookingVersion,
    required this.publishedAt,
    required this.updatedAt,
  }) : contactPhone = checkedContactPhone(contactPhone),
       notes = checkedText(notes.trim(), 'notes', 0, 500),
       legacyDirections = checkedDirections(legacyDirections),
       participationCondition = checkedParticipationCondition(
         participationCondition,
       ),
       announcementStatus = checkedAnnouncementStatus(announcementStatus),
       eventDirection = checkedEventDirection(eventDirection),
       eventFormat = checkedEventFormat(eventFormat),
       targetAudiences = checkedTargetAudiences(targetAudiences) {
    checkedText(title, 'title', 3, 120);
    checkedText(responsibleName, 'responsibleName', 0, 80);
    if (description.runes.length > 5000 ||
        roomNameSnapshot.runes.length > 80 ||
        locationSnapshot.runes.length > 160 ||
        bookingVersion < 1) {
      throw const DomainException(ErrorCode.validation, field: 'publicEvent');
    }
  }
  final String id,
      title,
      description,
      roomId,
      roomNameSnapshot,
      locationSnapshot,
      responsibleName;
  final String contactPhone, notes;
  final List<String> legacyDirections;
  final String participationCondition,
      announcementStatus,
      eventDirection,
      eventFormat;
  final List<String> targetAudiences;
  final bool hasStructuredFields;
  final CoverImage? coverImage;
  final BookingInterval interval;
  final int bookingVersion;
  final DateTime publishedAt, updatedAt;

  /// Structured direction chip, or legacy multi-tags for old documents.
  List<String> get directions =>
      hasStructuredFields ? [eventDirection] : legacyDirections;
}
