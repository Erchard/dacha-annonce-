import 'package:flutter_test/flutter_test.dart';
import 'package:dacha_annonce/features/bookings/domain/booking.dart';

void main() {
  test('room deletion uses Kyiv date and keeps today and future protected', () {
    final now = DateTime.utc(2026, 10, 21, 21, 30); // 22 October in Kyiv
    for (final status in [BookingStatus.pending, BookingStatus.approved]) {
      expect(
        bookingPreventsRoomDeletion(
          status,
          DateTime.utc(2026, 10, 21, 20, 30),
          now,
        ),
        false,
      );
      expect(
        bookingPreventsRoomDeletion(
          status,
          DateTime.utc(2026, 10, 21, 21),
          now,
        ),
        true,
      );
      expect(
        bookingPreventsRoomDeletion(status, DateTime.utc(2026, 10, 23), now),
        true,
      );
    }
    for (final status in [
      BookingStatus.cancelled,
      BookingStatus.rejected,
      BookingStatus.deleted,
    ]) {
      expect(
        bookingPreventsRoomDeletion(status, DateTime.utc(2026, 10, 23), now),
        false,
      );
    }
  });
}
