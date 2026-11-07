import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/time/time_zone_service.dart';
import '../../features/calendar/domain/public_event.dart';
import 'shared.dart';

/// MI month-grid palette (fills + weekday header chips). Independent of schedule.
const calendarHeaderBlue = Color(0xFF0869BA);
const calendarTodayGreen = Color(0xFF2E7D32);

const calendarWeekdayFill = <Color>[
  Color(0xFFEAF3E2), // Mon
  Color(0xFFFFF5E2), // Tue
  Color(0xFFFCE7E3), // Wed
  Color(0xFFEEE6FA), // Thu
  Color(0xFFDDEFFC), // Fri
  Color(0xFFFCE3F0), // Sat
  Color(0xFFE0FAF1), // Sun
];

const calendarWeekdayHeader = <Color>[
  Color(0xFFC9DDB8),
  Color(0xFFFBE8BD),
  Color(0xFFF8CFC3),
  Color(0xFFD6C3ED),
  Color(0xFFADD7F3),
  Color(0xFFF5C5E1),
  Color(0xFFB1EBD9),
];

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

bool _isPastDay(DateTime day) {
  final now = TimeZoneService().toKyiv(DateTime.now());
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).isBefore(DateTime(now.year, now.month, now.day));
}

bool _isToday(DateTime day) {
  final now = TimeZoneService().toKyiv(DateTime.now());
  return day.year == now.year && day.month == now.month && day.day == now.day;
}

/// Month calendar matching MI mockup: blue toolbar + pastel weekday columns.
class MiMonthCalendar extends StatelessWidget {
  const MiMonthCalendar({
    super.key,
    required this.month,
    required this.events,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onCreateEvent,
    required this.onDayTap,
    required this.onEventTap,
  });

  final DateTime month;
  final List<PublicEvent> events;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final VoidCallback onCreateEvent;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<PublicEvent> onEventTap;

  List<PublicEvent> _eventsOn(DateTime day) {
    final start = tz.TZDateTime(
      tz.getLocation('Europe/Kyiv'),
      day.year,
      day.month,
      day.day,
    ).toUtc();
    final end = tz.TZDateTime(
      tz.getLocation('Europe/Kyiv'),
      day.year,
      day.month,
      day.day + 1,
    ).toUtc();
    return events
        .where(
          (e) =>
              e.interval.start.isBefore(end) && e.interval.end.isAfter(start),
        )
        .toList()
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final title = DateFormat('LLLL yyyy', 'uk').format(month).toUpperCase();

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthToolbar(
          title: title,
          onPrev: onPrevMonth,
          onNext: onNextMonth,
          onToday: onToday,
          onCreate: onCreateEvent,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: calendarWeekdayHeader[i],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _weekdayLabels[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 8.0;
            final cellW = (constraints.maxWidth - gap * 6) / 7;
            final cellH = cellW.clamp(96.0, 200.0);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < total; index++)
                  SizedBox(
                    width: cellW,
                    height: cellH,
                    child: _MonthCell(
                      date: DateTime(
                        month.year,
                        month.month,
                        index - leading + 1,
                      ),
                      inMonth:
                          index >= leading && index < leading + daysInMonth,
                      events: () {
                        final d = DateTime(
                          month.year,
                          month.month,
                          index - leading + 1,
                        );
                        if (index < leading || index >= leading + daysInMonth) {
                          return const <PublicEvent>[];
                        }
                        return _eventsOn(d);
                      }(),
                      onDayTap: onDayTap,
                      onEventTap: onEventTap,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 720.0;
        if (constraints.maxWidth >= minWidth) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: grid),
        );
      },
    );
  }
}

class _MonthToolbar extends StatelessWidget {
  const _MonthToolbar({
    required this.title,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onCreate,
  });
  final String title;
  final VoidCallback onPrev, onNext, onToday, onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: calendarHeaderBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final brand = Container(
            width: compact ? 88 : 110,
            height: compact ? 48 : 56,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/brand/dacha_roof.jpg',
              fit: BoxFit.contain,
            ),
          );
          final nav = Row(
            children: [
              _headerIconButton(Icons.chevron_left, onPrev),
              _headerIconButton(Icons.chevron_right, onNext),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 18 : 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onToday,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Сьогодні'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Створити подію'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    brand,
                    const SizedBox(width: 10),
                    Container(width: 1, height: 36, color: Colors.white54),
                    const SizedBox(width: 10),
                    Expanded(child: nav),
                  ],
                ),
                const SizedBox(height: 10),
                actions,
              ],
            );
          }
          return Row(
            children: [
              brand,
              const SizedBox(width: 12),
              Container(width: 1, height: 36, color: Colors.white54),
              const SizedBox(width: 12),
              Expanded(child: nav),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onPressed) =>
      IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        style: IconButton.styleFrom(
          side: const BorderSide(color: Colors.white70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.inMonth,
    required this.events,
    required this.onDayTap,
    required this.onEventTap,
  });

  final DateTime date;
  final bool inMonth;
  final List<PublicEvent> events;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<PublicEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final fill = calendarWeekdayFill[date.weekday - 1];
    final header = calendarWeekdayHeader[date.weekday - 1];
    final today = inMonth && _isToday(date);
    final past = inMonth && _isPastDay(date);
    final shown = events.take(5).toList();
    final more = events.length - shown.length;

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: header.withValues(alpha: 0.85)),
      ),
      child: InkWell(
        onTap: () => onDayTap(date),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: today ? 36 : null,
                  height: today ? 36 : null,
                  alignment: Alignment.center,
                  decoration: today
                      ? const BoxDecoration(
                          color: calendarTodayGreen,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: inMonth ? 22 : 16,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: today
                          ? Colors.white
                          : !inMonth
                          ? Colors.black38
                          : past
                          ? Colors.black45
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final event in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: GestureDetector(
                          onTap: () => onEventTap(event),
                          child: Text(
                            '${localTime(event.interval.start)} ${event.title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              color: past
                                  ? Colors.black45
                                  : const Color(0xFF0B57A8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (more > 0)
                      Text(
                        '+$more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: calendarHeaderBlue,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
