import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

import '../errors/domain_exception.dart';

class TimeZoneService {
  TimeZoneService() {
    data.initializeTimeZones();
  }
  static const zoneName = 'Europe/Kyiv';
  tz.Location get _location => tz.getLocation(zoneName);
  tz.TZDateTime toKyiv(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), _location);

  // Zero candidates means a DST gap; two means an ambiguous local time.
  // The caller must let the user choose an instant; never normalize silently.
  List<DateTime> candidates({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
  }) {
    final wall = DateTime.utc(year, month, day, hour, minute);
    if (wall.year != year ||
        wall.month != month ||
        wall.day != day ||
        wall.hour != hour ||
        wall.minute != minute) {
      throw const DomainException(ErrorCode.validation, field: 'localTime');
    }
    final results = <DateTime>{};
    for (final offset in _location.zones.map((z) => z.offset).toSet()) {
      final instant = wall.subtract(offset);
      final local = toKyiv(instant);
      if (local.year == year &&
          local.month == month &&
          local.day == day &&
          local.hour == hour &&
          local.minute == minute &&
          local.second == 0) {
        results.add(instant);
      }
    }
    return List.unmodifiable(results.toList()..sort());
  }
}
