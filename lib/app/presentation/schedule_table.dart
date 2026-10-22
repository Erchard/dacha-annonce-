import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/time/time_zone_service.dart';
import '../../features/calendar/domain/public_event.dart';
import 'shared.dart';

class ScheduleTable extends StatelessWidget {
  const ScheduleTable({super.key, required this.events, required this.wide});
  final List<PublicEvent> events;
  final bool wide;
  static const headings = [
    'Дата',
    'Час',
    'Назва події',
    'Локація',
    'Відповідальний\nі телефон',
    'Примітки',
  ];
  static const widths = <int, TableColumnWidth>{
    0: FlexColumnWidth(1),
    1: FlexColumnWidth(.85),
    2: FlexColumnWidth(1.7),
    3: FlexColumnWidth(1.1),
    4: FlexColumnWidth(1.4),
    5: FlexColumnWidth(1.5),
  };
  static const colors = [
    Color(0xffe9efdf),
    Color(0xfff5ebce),
    Color(0xffe1edf1),
    Color(0xffeee4f0),
    Color(0xfff3e4da),
    Color(0xffe1eee7),
    Color(0xffece9dc),
  ];
  Widget cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: child,
  );
  Widget title(BuildContext context, PublicEvent event) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => context.go('/events/${Uri.encodeComponent(event.id)}'),
        child: Text(
          event.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      if (event.directions.isNotEmpty)
        Text(
          event.directions.join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );
  Widget contact(PublicEvent event) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(event.responsibleName.isEmpty ? '—' : event.responsibleName),
      if (event.contactPhone.isNotEmpty) ...[
        const SizedBox(height: 6),
        SelectableText(event.contactPhone),
      ],
    ],
  );
  String time(PublicEvent event) =>
      '${localTime(event.interval.start)}–${localTime(event.interval.end)}${localDate(event.interval.start) == localDate(event.interval.end) ? '' : ' (${localDate(event.interval.end)})'}';
  @override
  Widget build(BuildContext context) {
    final zone = TimeZoneService();
    final ordered = [...events]
      ..sort((a, b) {
        final byTime = a.interval.start.compareTo(b.interval.start);
        return byTime == 0 ? a.id.compareTo(b.id) : byTime;
      });
    final groups = <DateTime, List<PublicEvent>>{};
    for (final event in ordered) {
      final local = zone.toKyiv(event.interval.start);
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(event);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide && events.isNotEmpty)
          Table(
            columnWidths: widths,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xff315343)),
                children: [
                  for (final heading in headings)
                    cell(
                      Text(
                        heading,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        for (final entry in groups.entries) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: colors[entry.key.weekday - 1],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Text(
              DateFormat('d MMMM · EEEE', 'uk').format(entry.key),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (wide)
            Table(
              columnWidths: widths,
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xffe0e5dd)),
              ),
              children: [
                for (final event in entry.value)
                  TableRow(
                    children: [
                      cell(Text(localDate(event.interval.start))),
                      cell(
                        Text(
                          time(event),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      cell(title(context, event)),
                      cell(Text(event.roomNameSnapshot)),
                      cell(contact(event)),
                      cell(Text(event.notes.isEmpty ? '—' : event.notes)),
                    ],
                  ),
              ],
            )
          else
            for (final event in entry.value)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time(event),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      title(context, event),
                      Text(event.roomNameSnapshot),
                      const SizedBox(height: 8),
                      contact(event),
                      if (event.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(event.notes),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
