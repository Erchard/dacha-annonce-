import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/time/time_zone_service.dart';
import '../../core/widgets/app_link.dart';
import '../../core/widgets/direction_chip.dart';
import '../../features/calendar/domain/public_event.dart';
import 'shared.dart';

const scheduleCream = Color(0xfff5f5f0);
const scheduleInk = Color(0xff2f2f2a);
const scheduleMuted = Color(0xff6b6b63);
const scheduleGreen = Color(0xff315343);
const scheduleHeaderGreen = Color(0xff315343);

const scheduleDayColors = [
  Color(0xffe9efdf),
  Color(0xfff5ebce),
  Color(0xffe1edf1),
  Color(0xffeee4f0),
  Color(0xfff3e4da),
  Color(0xffe1eee7),
  Color(0xffece9dc),
];

TextStyle scheduleSerif({
  double size = 28,
  FontWeight weight = FontWeight.w600,
  Color color = scheduleInk,
}) => GoogleFonts.sourceSerif4(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.2,
);

class ScheduleBrandHeader extends StatelessWidget {
  const ScheduleBrandHeader({
    super.key,
    required this.view,
    required this.focus,
    this.roomLabel,
  });
  final String view;
  final DateTime focus;
  final String? roomLabel;

  Widget _roomLine() {
    final label = roomLabel?.trim();
    if (label == null || label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Локація: $label',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheduleGreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (view == 'day') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ГРОМАДСЬКИЙ ПРОСТІР «ДАЧА» · БОЯРКА',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: scheduleMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            roomLabel == null ? 'Зустрічаємося на Дачі' : 'Розклад локації',
            style: scheduleSerif(size: 34),
          ),
          const SizedBox(height: 6),
          Text(
            'Розклад подій · ${DateFormat('LLLL yyyy', 'uk').format(focus)}',
            style: const TextStyle(fontSize: 16, color: scheduleMuted),
          ),
          _roomLine(),
        ],
      );
    }
    if (view == 'month') {
      final month = DateFormat('LLLL yyyy', 'uk').format(focus);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roomLabel == null ? 'Місяць на Дачі' : 'Місяць локації',
            style: scheduleSerif(size: 34),
          ),
          const SizedBox(height: 6),
          Text(
            '${month[0].toUpperCase()}${month.substring(1)}',
            style: const TextStyle(fontSize: 16, color: scheduleMuted),
          ),
          _roomLine(),
          const SizedBox(height: 8),
          Text(
            roomLabel == null
                ? 'Усі події місяця в одній таблиці — дні з кольорами тижня.'
                : 'Лише події цієї локації за місяць.',
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: scheduleMuted,
            ),
          ),
        ],
      );
    }
    final monday = DateTime(
      focus.year,
      focus.month,
      focus.day - (focus.weekday - 1),
    );
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final range = monday.month == sunday.month
        ? '${DateFormat('d', 'uk').format(monday)}–${DateFormat('d MMMM yyyy', 'uk').format(sunday)} року'
        : '${DateFormat('d MMM', 'uk').format(monday)} – ${DateFormat('d MMM yyyy', 'uk').format(sunday)} року';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roomLabel == null ? 'Тиждень на Дачі' : 'Тиждень локації',
          style: scheduleSerif(size: 34),
        ),
        const SizedBox(height: 6),
        Text(range, style: const TextStyle(fontSize: 16, color: scheduleMuted)),
        _roomLine(),
        const SizedBox(height: 8),
        Text(
          roomLabel == null
              ? 'Кожен день тижня має свій колір у таблиці нижче.'
              : 'Події лише цієї локації; дні з кольорами тижня.',
          style: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: scheduleMuted,
          ),
        ),
      ],
    );
  }
}

class ScheduleTable extends StatelessWidget {
  const ScheduleTable({
    super.key,
    required this.events,
    required this.wide,
    required this.view,
  });
  final List<PublicEvent> events;
  final bool wide;
  final String view;

  static const headings = [
    'Дата',
    'Час',
    'Назва події',
    'Локація',
    'Відповідальний\nі телефон',
    'Примітки',
  ];

  Map<DateTime, List<PublicEvent>> groups() {
    final zone = TimeZoneService();
    final ordered = [...events]
      ..sort((a, b) {
        final byTime = a.interval.start.compareTo(b.interval.start);
        return byTime == 0 ? a.id.compareTo(b.id) : byTime;
      });
    final result = <DateTime, List<PublicEvent>>{};
    for (final event in ordered) {
      final local = zone.toKyiv(event.interval.start);
      final day = DateTime(local.year, local.month, local.day);
      result.putIfAbsent(day, () => []).add(event);
    }
    return result;
  }

  String timeLabel(PublicEvent event) {
    final sameDay =
        localDate(event.interval.start) == localDate(event.interval.end);
    return '${localTime(event.interval.start)}–${localTime(event.interval.end)}'
        '${sameDay ? '' : ' (${localDate(event.interval.end)})'}';
  }

  String dateCell(DateTime day) =>
      '${DateFormat('dd.MM.yyyy', 'uk').format(day)} '
      '${DateFormat('EEEE', 'uk').format(day)}';

  String dayCountLabel(int count) {
    final mod10 = count % 10, mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count подія';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count події';
    }
    return '$count подій';
  }

  Widget eventTitle(BuildContext context, PublicEvent event) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppLink(
        to: '/events/${Uri.encodeComponent(event.id)}',
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        child: Text(
          event.title,
          style: scheduleSerif(size: 18, color: scheduleGreen),
        ),
      ),
      if (event.directions.isNotEmpty) ...[
        const SizedBox(height: 6),
        DirectionChipWrap(directions: event.directions.take(3)),
      ],
    ],
  );

  int columnFlex(String heading) {
    if (heading.startsWith('Назва')) return 15;
    if (heading.startsWith('Відповідальний')) return 12;
    if (heading == 'Примітки') return 22;
    if (heading == 'Дата') return 11;
    if (heading == 'Час') return 8;
    return 10;
  }

  Widget notesCell(PublicEvent event) {
    final text = event.notes.trim();
    if (text.isEmpty) {
      return const Text('—', style: TextStyle(color: scheduleMuted));
    }
    return Text(
      text,
      softWrap: true,
      overflow: TextOverflow.visible,
      style: const TextStyle(
        fontSize: 13,
        height: 1.35,
        color: scheduleInk,
      ),
    );
  }

  Widget contact(PublicEvent event) {
    final name = event.responsibleName.trim();
    final phone = event.contactPhone.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? '—' : name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: scheduleInk,
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            phone.isEmpty ? 'Контакт уточнюється' : phone,
            style: TextStyle(
              fontSize: 13,
              color: phone.isEmpty ? scheduleMuted : scheduleInk.withValues(alpha: 0.75),
            ),
          ),
        ] else if (phone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(phone, style: const TextStyle(fontSize: 13)),
        ],
      ],
    );
  }

  Widget padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final byDay = groups();
    if (byDay.isEmpty) return const SizedBox.shrink();
    if (!wide) return _narrow(context, byDay);
    return view == 'day' ? _wideDay(context, byDay) : _wideWeek(context, byDay);
  }

  Widget _headerRow() => Container(
    color: scheduleHeaderGreen,
    child: Row(
      children: [
        for (final heading in headings)
          Expanded(
            flex: columnFlex(heading),
            child: padded(
              Text(
                heading,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _wideDay(
    BuildContext context,
    Map<DateTime, List<PublicEvent>> byDay,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in byDay.entries) ...[
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheduleDayColors[entry.key.weekday - 1],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMMM · EEEE', 'uk').format(entry.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheduleInk,
                    ),
                  ),
                ),
                Text(
                  dayCountLabel(entry.value.length),
                  style: const TextStyle(color: scheduleMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 960),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width.clamp(960, 1200),
                child: Column(
                  children: [
                    _headerRow(),
                    for (var i = 0; i < entry.value.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xffe0e5dd),
                              width: i == entry.value.length - 1 ? 0 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: columnFlex('Дата'),
                              child: padded(Text(dateCell(entry.key))),
                            ),
                            Expanded(
                              flex: columnFlex('Час'),
                              child: padded(
                                Text(
                                  timeLabel(entry.value[i]),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: columnFlex('Назва'),
                              child: padded(eventTitle(context, entry.value[i])),
                            ),
                            Expanded(
                              flex: columnFlex('Локація'),
                              child: padded(
                                Text(entry.value[i].roomNameSnapshot),
                              ),
                            ),
                            Expanded(
                              flex: columnFlex('Відповідальний'),
                              child: padded(contact(entry.value[i])),
                            ),
                            Expanded(
                              flex: columnFlex('Примітки'),
                              child: padded(notesCell(entry.value[i])),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _wideWeek(
    BuildContext context,
    Map<DateTime, List<PublicEvent>> byDay,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 960),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width.clamp(960, 1200),
              child: Column(
                children: [
                  _headerRow(),
                  for (final entry in byDay.entries) ...[
                    const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 118,
                            padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                            color: scheduleDayColors[entry.key.weekday - 1],
                            child: Text(
                              dateCell(entry.key),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: scheduleDayColors[entry.key.weekday - 1]
                                  .withValues(alpha: 0.55),
                              child: Column(
                                children: [
                                  for (var i = 0; i < entry.value.length; i++)
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            width:
                                                i == entry.value.length - 1
                                                ? 0
                                                : 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: columnFlex('Час'),
                                            child: padded(
                                              Text(
                                                timeLabel(entry.value[i]),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: columnFlex('Назва'),
                                            child: padded(
                                              eventTitle(
                                                context,
                                                entry.value[i],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: columnFlex('Локація'),
                                            child: padded(
                                              Text(
                                                entry.value[i].roomNameSnapshot,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: columnFlex('Відповідальний'),
                                            child: padded(
                                              contact(entry.value[i]),
                                            ),
                                          ),
                                          Expanded(
                                            flex: columnFlex('Примітки'),
                                            child: padded(
                                              notesCell(entry.value[i]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(
    BuildContext context,
    Map<DateTime, List<PublicEvent>> byDay,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in byDay.entries) ...[
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheduleDayColors[entry.key.weekday - 1],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('d MMMM · EEEE', 'uk').format(entry.key),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  dayCountLabel(entry.value.length),
                  style: const TextStyle(fontSize: 12, color: scheduleMuted),
                ),
              ],
            ),
          ),
          for (final event in entry.value)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: scheduleDayColors[entry.key.weekday - 1].withValues(
                  alpha: 0.45,
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xffe0e5dd)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel(event),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  eventTitle(context, event),
                  const SizedBox(height: 6),
                  Text(event.roomNameSnapshot),
                  const SizedBox(height: 8),
                  contact(event),
                  if (event.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Примітки',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheduleMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    notesCell(event),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}
