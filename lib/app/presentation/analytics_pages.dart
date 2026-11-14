import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/domain/page.dart';
import '../../core/time/time_zone_service.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/bookings/domain/event_details.dart';
import '../../features/calendar/domain/public_event.dart';
import '../providers.dart';
import 'shared.dart';

class AnalyticsReport {
  AnalyticsReport({
    required this.from,
    required this.to,
    required this.total,
    required this.byDirection,
    required this.byOrganizer,
    required this.byRoom,
  });
  final DateTime from;
  final DateTime to;
  final int total;
  final Map<String, int> byDirection;
  final Map<String, int> byOrganizer;
  final Map<String, int> byRoom;

  String summaryText() {
    final range =
        '${DateFormat('d MMMM yyyy', 'uk').format(from)} — '
        '${DateFormat('d MMMM yyyy', 'uk').format(to)}';
    final topDirections = _topLines(byDirection, 5);
    final topRooms = _topLines(byRoom, 5);
    final topOrganizers = _topLines(byOrganizer, 5);
    return 'За період $range опубліковано $total подій. '
        'Найчастіші напрямки: $topDirections. '
        'Найактивніші локації: $topRooms. '
        'Найактивніші організатори: $topOrganizers.';
  }

  String _topLines(Map<String, int> counts, int limit) {
    if (counts.isEmpty) return 'немає даних';
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => '${e.key} (${e.value})')
        .join(', ');
  }
}

class AdminAnalyticsPage extends ConsumerStatefulWidget {
  const AdminAnalyticsPage({super.key});
  @override
  ConsumerState<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends ConsumerState<AdminAnalyticsPage> {
  late DateTime from;
  late DateTime to;
  final Set<String> selectedDirections = {};
  bool busy = false;
  Object? error;
  AnalyticsReport? report;

  @override
  void initState() {
    super.initState();
    final now = TimeZoneService().toKyiv(DateTime.now());
    to = DateTime(now.year, now.month, now.day);
    from = DateTime(now.year, now.month - 1, now.day);
  }

  Future<void> pickDay({required bool isFrom}) async {
    final initial = isFrom ? from : to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('uk'),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        from = DateTime(picked.year, picked.month, picked.day);
      } else {
        to = DateTime(picked.year, picked.month, picked.day);
      }
      report = null;
      error = null;
    });
  }

  Future<List<PublicEvent>> loadPublished(
    DateTime rangeStart,
    DateTime rangeEndExclusive,
    List<String> directions,
  ) async {
    final repo = ref.read(repositoryProvider);
    final byId = <String, PublicEvent>{};
    Future<void> exhaust(List<String> directionChunk) async {
      var cursor = rangeStart.toUtc();
      final limit = rangeEndExclusive.toUtc();
      while (cursor.isBefore(limit)) {
        final chunkEnd = cursor.add(const Duration(days: 60)).isAfter(limit)
            ? limit
            : cursor.add(const Duration(days: 60));
        PageCursor? page;
        do {
          final result = await repo.listRange(
            cursor,
            chunkEnd,
            PageRequest(limit: 100, after: page),
            directions: directionChunk,
          );
          for (final event in result.items) {
            byId[event.id] = event;
          }
          page = result.next;
        } while (page != null);
        cursor = chunkEnd;
      }
    }

    if (directions.isEmpty) {
      await exhaust(const []);
    } else {
      for (var i = 0; i < directions.length; i += 10) {
        final end = i + 10 > directions.length ? directions.length : i + 10;
        await exhaust(directions.sublist(i, end));
      }
    }
    final events = byId.values.toList()
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
    return events;
  }

  Future<Map<String, String>> loadOrganizerNames() async {
    final repo = ref.read(repositoryProvider);
    final names = <String, String>{};
    PageCursor? page;
    do {
      final result = await repo.listProfiles(
        PageRequest(limit: 100, after: page),
        role: UserRole.organizer,
      );
      for (final profile in result.items) {
        names[profile.id] = profile.displayName.trim();
      }
      page = result.next;
    } while (page != null);
    return names;
  }

  Future<Map<String, int>> countByOrganizer(List<PublicEvent> events) async {
    final repo = ref.read(repositoryProvider);
    final names = await loadOrganizerNames();
    final counts = <String, int>{};
    for (var i = 0; i < events.length; i += 10) {
      final chunk = events.skip(i).take(10);
      final bookings = await Future.wait(
        chunk.map((event) => repo.getBooking(event.id)),
      );
      for (final booking in bookings) {
        if (booking == null) {
          counts['Невідомий організатор'] =
              (counts['Невідомий організатор'] ?? 0) + 1;
          continue;
        }
        final label =
            names[booking.organizerId] ??
            'Організатор ${booking.organizerId.substring(0, 6)}…';
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> run() async {
    if (!from.isBefore(to.add(const Duration(days: 1)))) {
      setState(() {
        error = 'Дата початку має бути не пізніше дати кінця.';
        report = null;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
      report = null;
    });
    try {
      final rangeEnd = to.add(const Duration(days: 1));
      final events = await loadPublished(
        from,
        rangeEnd,
        selectedDirections.toList()..sort(),
      );
      final byDirection = <String, int>{};
      final byRoom = <String, int>{};
      for (final event in events) {
        final roomLabel = event.roomNameSnapshot.trim().isEmpty
            ? event.roomId
            : event.roomNameSnapshot;
        byRoom[roomLabel] = (byRoom[roomLabel] ?? 0) + 1;
        if (event.hasStructuredFields) {
          byDirection[event.eventDirection] =
              (byDirection[event.eventDirection] ?? 0) + 1;
        } else if (event.legacyDirections.isEmpty) {
          byDirection['Без напрямку'] =
              (byDirection['Без напрямку'] ?? 0) + 1;
        } else {
          for (final direction in event.legacyDirections) {
            byDirection[direction] = (byDirection[direction] ?? 0) + 1;
          }
        }
      }
      final byOrganizer = await countByOrganizer(events);
      if (!mounted) return;
      setState(() {
        report = AnalyticsReport(
          from: from,
          to: to,
          total: events.length,
          byDirection: byDirection,
          byOrganizer: byOrganizer,
          byRoom: byRoom,
        );
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        busy = false;
        report = null;
      });
    }
  }

  Widget countsBlock(String title, Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('Немає даних')
        else
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key}: ${entry.value}'),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM yyyy', 'uk');
    return AppFrame(
      title: 'Аналітика',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Звіт лише за опублікованими подіями. Оберіть період і за потреби '
            'напрямки, потім натисніть «Показати».',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => pickDay(isFrom: true),
                child: Text('Від: ${dateLabel.format(from)}'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => pickDay(isFrom: false),
                child: Text('До: ${dateLabel.format(to)}'),
              ),
              FilledButton(
                onPressed: busy ? null : run,
                child: Text(busy ? 'Завантаження…' : 'Показати'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Тематика (напрямки)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
          for (final direction in eventDirectionOptions)
            FilterChip(
              label: Text(direction),
              selected: selectedDirections.contains(direction),
                  onSelected: busy
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              selectedDirections.add(direction);
                            } else {
                              selectedDirections.remove(direction);
                            }
                            report = null;
                            error = null;
                          });
                        },
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              'Не вдалося зібрати аналітику: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 24),
            Text('І. Загальний аналіз', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(report!.summaryText()),
            const SizedBox(height: 24),
            Text('ІІ. Статистика', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('1. Загальна кількість подій: ${report!.total}'),
            const SizedBox(height: 16),
            countsBlock('2. Кількість подій за напрямками', report!.byDirection),
            const SizedBox(height: 16),
            countsBlock(
              '3. Кількість подій за організаторами',
              report!.byOrganizer,
            ),
            const SizedBox(height: 16),
            countsBlock('4. Кількість подій за локаціями', report!.byRoom),
            const SizedBox(height: 8),
            const Text(
              'Подія з кількома напрямками входить у кожен обраний напрямок окремо.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
