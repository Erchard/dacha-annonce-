import '../../../core/errors/domain_exception.dart';
import '../../../core/time/booking_time.dart';
import '../../../core/time/time_zone_service.dart';

class WeekDate {
  const WeekDate({required this.day, this.interval, this.problem});
  final DateTime day;
  final BookingInterval? interval;
  final String? problem;
  String get label =>
      '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year.toString().padLeft(4, '0')}';
  String get key =>
      '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
}

/// Finite weekly copies of one Kyiv wall-clock interval, inclusive of [until].
/// The first date keeps the already chosen instants. Later dates are resolved
/// again: a DST gap or an ambiguous hour is reported and is not shifted.
List<WeekDate> weeklyDates({
  required DateTime start,
  required DateTime end,
  required DateTime until,
}) {
  final zone = TimeZoneService();
  final startLocal = zone.toKyiv(start);
  final endLocal = zone.toKyiv(end);
  final firstDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
  final untilDay = DateTime(until.year, until.month, until.day);
  final endIsNextDay = DateTime(
    endLocal.year,
    endLocal.month,
    endLocal.day,
  ).isAfter(firstDay);
  if (untilDay.isBefore(firstDay)) {
    return [
      WeekDate(
        day: untilDay,
        problem: 'Дата завершення раніша за першу подію.',
      ),
    ];
  }
  final dates = <WeekDate>[];
  for (var week = 0; ; week++) {
    final day = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day + 7 * week,
    );
    if (day.isAfter(untilDay)) return dates;
    if (week == 26) {
      return [
        WeekDate(
          day: day,
          problem: 'Оберіть дату завершення в межах 26 тижнів.',
        ),
      ];
    }
    if (week == 0) {
      dates.add(WeekDate(day: day, interval: BookingInterval(start, end)));
      continue;
    }
    final endDay = DateTime(
      day.year,
      day.month,
      day.day + (endIsNextDay ? 1 : 0),
    );
    final starts = zone.candidates(
      year: day.year,
      month: day.month,
      day: day.day,
      hour: startLocal.hour,
      minute: startLocal.minute,
    );
    final ends = zone.candidates(
      year: endDay.year,
      month: endDay.month,
      day: endDay.day,
      hour: endLocal.hour,
      minute: endLocal.minute,
    );
    if (starts.length != 1 || ends.length != 1) {
      dates.add(
        WeekDate(
          day: day,
          problem: starts.isEmpty || ends.isEmpty
              ? 'Цього часу не існує через переведення годинника.'
              : 'Цей час трапляється двічі через переведення годинника. Створіть цю дату окремо.',
        ),
      );
      continue;
    }
    try {
      dates.add(
        WeekDate(
          day: day,
          interval: BookingInterval(starts.single, ends.single),
        ),
      );
    } on DomainException {
      dates.add(
        WeekDate(
          day: day,
          problem: 'Цей інтервал не підходить для бронювання.',
        ),
      );
    }
  }
}
