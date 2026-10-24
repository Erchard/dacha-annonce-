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
    List<String> directions = const [],
    this.coverImage,
    required this.bookingVersion,
    required this.publishedAt,
    required this.updatedAt,
  }) : contactPhone = checkedContactPhone(contactPhone),
       notes = checkedText(notes.trim(), 'notes', 0, 500),
       directions = checkedDirections(directions) {
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
  final List<String> directions;
  final CoverImage? coverImage;
  final BookingInterval interval;
  final int bookingVersion;
  final DateTime publishedAt, updatedAt;
}
