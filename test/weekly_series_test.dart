import 'package:dacha_annonce/core/time/time_zone_service.dart';
import 'package:dacha_annonce/features/bookings/domain/weekly_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zone = TimeZoneService();
  DateTime at(int year, int month, int day, int hour, int minute) => zone
      .candidates(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
      )
      .single;

  test('weekly dates stay on the Kyiv wall clock across the spring change', () {
    final start = at(2026, 3, 22, 10, 0);
    final dates = weeklyDates(
      start: start,
      end: start.add(const Duration(hours: 1)),
      until: DateTime(2026, 4, 5),
    );
    expect(dates.map((date) => date.label), [
      '22.03.2026',
      '29.03.2026',
      '05.04.2026',
    ]);
    expect(dates.every((date) => date.problem == null), isTrue);
    expect(dates.map((date) => zone.toKyiv(date.interval!.start).hour), [
      10,
      10,
      10,
    ]);
  });

  test('a DST gap is reported and the valid weeks stay unchanged', () {
    final start = at(2026, 3, 22, 3, 30);
    final dates = weeklyDates(
      start: start,
      end: start.add(const Duration(hours: 1)),
      until: DateTime(2026, 3, 29),
    );
    expect(dates.first.problem, isNull);
    expect(dates.last.label, '29.03.2026');
    expect(dates.last.interval, isNull);
    expect(dates.last.problem, contains('не існує'));
  });

  test('an ambiguous hour is reported instead of choosing an offset', () {
    final start = at(2026, 10, 18, 3, 30);
    final dates = weeklyDates(
      start: start,
      end: start.add(const Duration(minutes: 30)),
      until: DateTime(2026, 10, 25),
    );
    expect(dates.last.problem, contains('двічі'));
  });

  test('until before the first date and a 27th week are refused', () {
    final start = at(2026, 6, 1, 10, 0);
    expect(
      weeklyDates(
        start: start,
        end: start.add(const Duration(hours: 1)),
        until: DateTime(2026, 5, 1),
      ).single.problem,
      contains('раніша'),
    );
    expect(
      weeklyDates(
        start: start,
        end: start.add(const Duration(hours: 1)),
        until: DateTime(2026, 12, 7),
      ).single.problem,
      contains('26 тижнів'),
    );
  });
}
