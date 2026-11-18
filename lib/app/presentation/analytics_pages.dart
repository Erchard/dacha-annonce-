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
    required this.byParticipation,
    required this.byAnnouncement,
    required this.byFormat,
    required this.byRoom,
    required this.notesLines,
  });
  final DateTime from;
  final DateTime to;
  final int total;
  final Map<String, int> byDirection;
  final Map<String, int> byParticipation;
  final Map<String, int> byAnnouncement;
  final Map<String, int> byFormat;
  final Map<String, int> byRoom;
  final List<String> notesLines;

  String summaryText() {
    final range =
        '${DateFormat('d MMMM yyyy', 'uk').format(from)} — '
        '${DateFormat('d MMMM yyyy', 'uk').format(to)}';
    final postponed = byAnnouncement['postponed'] ?? 0;
    final cancelled = byAnnouncement['cancelled'] ?? 0;
    final buffer = StringBuffer(
      'За період $range опубліковано $total подій. '
      'Найчастіші напрямки: ${_topLines(byDirection, 5)}. '
      'Найактивніші локації: ${_topLines(byRoom, 5)}. '
      'Перенесено: $postponed, скасовано в афіші: $cancelled.',
    );
    if (notesLines.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
      buffer.write('За матеріалами приміток: ${notesLines.join(' ')}');
    }
    return buffer.toString();
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
    DateTime start,
    DateTime end,
    List<String> directions,
  ) async {
    final repo = ref.read(repositoryProvider);
    final byId = <String, PublicEvent>{};

    Future<void> exhaust(List<String> directionChunk) async {
      PageCursor? cursor;
      do {
        final page = await repo.listRange(
          start,
          end,
          PageRequest(limit: 100, after: cursor),
          directions: directionChunk,
        );
        for (final event in page.items) {
          byId[event.id] = event;
        }
        cursor = page.next;
      } while (cursor != null);
    }

    if (directions.isEmpty) {
      await exhaust(const []);
    } else {
      for (var i = 0; i < directions.length; i += 10) {
        final endIdx = i + 10 > directions.length
            ? directions.length
            : i + 10;
        await exhaust(directions.sublist(i, endIdx));
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.interval.start.compareTo(b.interval.start));
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
      final byParticipation = <String, int>{};
      final byAnnouncement = <String, int>{};
      final byFormat = <String, int>{};
      final byRoom = <String, int>{};
      final notesLines = <String>[];
      for (final event in events) {
        final roomLabel = event.roomNameSnapshot.trim().isEmpty
            ? event.roomId
            : event.roomNameSnapshot;
        byRoom[roomLabel] = (byRoom[roomLabel] ?? 0) + 1;
        if (event.hasStructuredFields) {
          byDirection[event.eventDirection] =
              (byDirection[event.eventDirection] ?? 0) + 1;
          byParticipation[event.participationCondition] =
              (byParticipation[event.participationCondition] ?? 0) + 1;
          byAnnouncement[event.announcementStatus] =
              (byAnnouncement[event.announcementStatus] ?? 0) + 1;
          byFormat[event.eventFormat] = (byFormat[event.eventFormat] ?? 0) + 1;
        } else if (event.legacyDirections.isEmpty) {
          byDirection['Без напрямку'] = (byDirection['Без напрямку'] ?? 0) + 1;
        } else {
          for (final direction in event.legacyDirections) {
            byDirection[direction] = (byDirection[direction] ?? 0) + 1;
          }
        }
        final note = event.notes.trim();
        if (note.isNotEmpty) {
          notesLines.add('«$note» (${event.title}).');
        }
      }
      if (!mounted) return;
      setState(() {
        report = AnalyticsReport(
          from: from,
          to: to,
          total: events.length,
          byDirection: byDirection,
          byParticipation: byParticipation,
          byAnnouncement: byAnnouncement,
          byFormat: byFormat,
          byRoom: byRoom,
          notesLines: notesLines,
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
    final profile = ref.watch(profileProvider).asData?.value;
    if (profile?.role != UserRole.admin) {
      return const AppFrame(
        title: 'Аналітика',
        child: Text('Доступно лише адміністратору.'),
      );
    }
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
          Text(
            'Напрям діяльності',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            Text(
              'І. Загальний аналіз',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(report!.summaryText()),
            const SizedBox(height: 24),
            Text(
              'ІІ. Статистика',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('1. Загальна кількість подій: ${report!.total}'),
            const SizedBox(height: 16),
            countsBlock(
              '2. Кількість подій за напрямками',
              report!.byDirection,
            ),
            const SizedBox(height: 16),
            countsBlock(
              '3. Кількість подій за умовами участі',
              report!.byParticipation,
            ),
            const SizedBox(height: 16),
            countsBlock(
              '4. Кількість скасованих та перенесених подій',
              {
                'Перенесено': report!.byAnnouncement['postponed'] ?? 0,
                'Скасовано': report!.byAnnouncement['cancelled'] ?? 0,
              },
            ),
            const SizedBox(height: 16),
            countsBlock(
              '5. Кількість за форматом подій',
              report!.byFormat,
            ),
            const SizedBox(height: 16),
            countsBlock(
              '6. Кількість подій по кожній з локацій',
              report!.byRoom,
            ),
          ],
        ],
      ),
    );
  }
}
