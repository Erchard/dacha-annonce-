import 'package:flutter_test/flutter_test.dart';
import 'package:dacha_annonce/core/errors/domain_exception.dart';
import 'package:dacha_annonce/core/time/booking_time.dart';
import 'package:dacha_annonce/core/time/time_zone_service.dart';

void main() {
  test('half-open UTC intervals and canonical two-block occupancy', () {
    final start = DateTime.utc(2026, 10, 5, 0, 30);
    final interval = BookingInterval(
      start,
      start.add(const Duration(hours: 6)),
    );
    expect(interval.blockIds, ['1791158400', '1791180000']);
    expect(interval.slotsByBlock.values.map((s) => s.length), [11, 1]);
    expect(
      interval.overlaps(
        BookingInterval(
          interval.end,
          interval.end.add(const Duration(minutes: 30)),
        ),
      ),
      isFalse,
    );
    expect(
      BookingInterval(
        DateTime.utc(2026, 10, 5),
        DateTime.utc(2026, 10, 5, 6),
      ).blockIds.length,
      1,
    );
  });
  test(
    'reject sub-slot time, reversed interval, excessive duration and horizon',
    () {
      final start = DateTime.utc(2026, 10, 5);
      for (final offset in [
        const Duration(microseconds: 1),
        const Duration(minutes: 1),
      ]) {
        expect(
          () => BookingInterval(
            start.add(offset),
            start.add(const Duration(hours: 1)),
          ),
          throwsA(isA<DomainException>()),
        );
      }
      expect(
        () => BookingInterval(start, start),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => BookingInterval(start, start.add(const Duration(hours: 7))),
        throwsA(isA<DomainException>()),
      );
      final interval = BookingInterval(
        start,
        start.add(const Duration(hours: 1)),
      );
      expect(
        () => interval.validateFuture(FixedClock(start)),
        throwsA(isA<DomainException>()),
      );
      interval.validateFuture(
        FixedClock(start.subtract(const Duration(days: 180))),
      );
      expect(
        () => interval.validateFuture(
          FixedClock(start.subtract(const Duration(days: 181))),
        ),
        throwsA(isA<DomainException>()),
      );
    },
  );
  test('Kyiv DST gap and ambiguity are explicit', () {
    final time = TimeZoneService();
    expect(
      time.candidates(year: 2026, month: 3, day: 29, hour: 3, minute: 30),
      isEmpty,
    );
    final overlap = time.candidates(
      year: 2026,
      month: 10,
      day: 25,
      hour: 3,
      minute: 30,
    );
    expect(overlap, [
      DateTime.utc(2026, 10, 25, 0, 30),
      DateTime.utc(2026, 10, 25, 1, 30),
    ]);
    expect(time.candidates(year: 2026, month: 7, day: 1, hour: 12, minute: 0), [
      DateTime.utc(2026, 7, 1, 9),
    ]);
    expect(
      () => time.candidates(year: 2026, month: 2, day: 30, hour: 12, minute: 0),
      throwsA(isA<DomainException>()),
    );
  });
}
