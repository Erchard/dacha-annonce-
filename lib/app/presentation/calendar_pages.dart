import 'schedule_table.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/domain/page.dart';
import '../../core/time/time_zone_service.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/bookings/domain/event_details.dart';
import '../../features/calendar/domain/public_event.dart';
import '../../features/rooms/domain/room.dart';
import '../providers.dart';
import 'shared.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({
    super.key,
    this.date,
    this.roomId,
    this.view,
    this.pagePath = '/',
  });
  final String? date, roomId, view;
  final String pagePath;
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static const views = {'day', 'week', 'month', 'list'};
  late DateTime focus;
  late String view;
  List<PublicEvent> events = [];
  List<Room> rooms = [];
  final Set<String> selectedDirections = {};
  PageCursor? next, roomNext;
  bool busy = true;
  int generation = 0;
  Object? error;
  String? invalidDate;

  DateTime civil(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void readQuery() {
    final now = civil(TimeZoneService().toKyiv(DateTime.now()));
    final parsed = widget.date == null ? null : DateTime.tryParse(widget.date!);
    invalidDate =
        widget.date != null &&
            (parsed == null ||
                DateFormat('yyyy-MM-dd').format(parsed) != widget.date)
        ? 'Некоректна дата в посиланні.'
        : null;
    focus = parsed == null ? now : civil(parsed);
    view = widget.pagePath == '/schedule'
        ? (const {'day', 'week', 'month'}.contains(widget.view)
              ? widget.view!
              : 'week')
        : views.contains(widget.view)
        ? widget.view!
        : 'month';
  }

  ({DateTime start, DateTime end}) window() {
    final location = tz.getLocation('Europe/Kyiv');
    DateTime at(int year, int month, int day) =>
        tz.TZDateTime(location, year, month, day).toUtc();
    if (view == 'day') {
      return (
        start: at(focus.year, focus.month, focus.day),
        end: at(focus.year, focus.month, focus.day + 1),
      );
    }
    if (view == 'week') {
      final monday = DateTime(
        focus.year,
        focus.month,
        focus.day - (focus.weekday - 1),
      );
      return (
        start: at(monday.year, monday.month, monday.day),
        end: at(monday.year, monday.month, monday.day + 7),
      );
    }
    return (
      start: at(focus.year, focus.month, 1),
      end: at(focus.year, focus.month + 1, 1),
    );
  }

  @override
  void initState() {
    super.initState();
    readQuery();
    Future.microtask(() => load(reset: true));
  }

  @override
  void didUpdateWidget(CalendarPage old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date ||
        old.roomId != widget.roomId ||
        old.view != widget.view ||
        old.pagePath != widget.pagePath) {
      readQuery();
      load(reset: true);
    }
  }

  Future<void> load({required bool reset}) async {
    final request = ++generation;
    if (invalidDate != null) {
      setState(() => busy = false);
      return;
    }
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        events = [];
        next = null;
      }
    });
    final requestedDate = widget.date,
        requestedRoom = widget.roomId,
        requestedView = widget.view;
    try {
      final repo = ref.read(repositoryProvider);
      final range = window();
      final page = await repo.listRange(
        range.start,
        range.end,
        PageRequest(after: reset ? null : next),
        roomId: widget.roomId,
        directions: selectedDirections.toList()..sort(),
      );
      final roomPage = rooms.isEmpty
          ? await repo.listRooms(PageRequest(limit: 100))
          : null;
      if (mounted &&
          request == generation &&
          requestedDate == widget.date &&
          requestedRoom == widget.roomId &&
          requestedView == widget.view) {
        setState(() {
          events = reset ? page.items : [...events, ...page.items];
          next = page.next;
          if (roomPage != null) {
            rooms = roomPage.items;
            roomNext = roomPage.next;
          }
        });
      }
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  void navigate(
    DateTime date, {
    String? nextView,
    String? room,
    bool changeRoom = false,
  }) {
    final selectedRoom = changeRoom ? room : widget.roomId;
    final params = {
      'date': DateFormat('yyyy-MM-dd').format(civil(date)),
      'view': nextView ?? view,
      'room': ?selectedRoom,
    };
    context.go(Uri(path: widget.pagePath, queryParameters: params).toString());
  }

  String periodLabel() {
    if (view == 'day') return DateFormat('d MMMM yyyy', 'uk').format(focus);
    if (view == 'week') {
      final monday = DateTime(
        focus.year,
        focus.month,
        focus.day - (focus.weekday - 1),
      );
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return '${DateFormat('d MMM', 'uk').format(monday)} – ${DateFormat('d MMM yyyy', 'uk').format(sunday)}';
    }
    return DateFormat('LLLL yyyy', 'uk').format(focus);
  }

  void book(bool signedIn, bool admin) {
    final target = admin ? '/admin/events/new' : '/bookings/new';
    final destination = Uri(
      path: target,
      queryParameters: {'room': ?widget.roomId},
    ).toString();
    context.go(
      signedIn
          ? destination
          : '/login?returnTo=${Uri.encodeComponent(destination)}',
    );
  }

  bool get isSchedule => widget.pagePath == '/schedule';
  bool get lockedRoom => isSchedule && widget.roomId != null;
  String? lockedRoomName() {
    final id = widget.roomId;
    if (id == null) return null;
    return rooms.where((r) => r.id == id).map((r) => r.name).firstOrNull ??
        'обрана локація';
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionProvider).asData?.value != null;
    final admin =
        ref.watch(profileProvider).asData?.value?.role == UserRole.admin;
    final step = switch (view) {
      'day' => 1,
      'week' => 7,
      _ => 0,
    };
    final viewChoices = isSchedule
        ? const [('day', 'День'), ('week', 'Тиждень'), ('month', 'Місяць')]
        : const [
            ('day', 'День'),
            ('week', 'Тиждень'),
            ('month', 'Місяць'),
            ('list', 'Список'),
          ];
    return AppFrame(
      backgroundColor: isSchedule ? scheduleCream : null,
      title: isSchedule ? 'Розклад' : 'Календар',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSchedule)
            ScheduleBrandHeader(
              view: view,
              focus: focus,
              roomLabel: lockedRoom ? lockedRoomName() : null,
            )
          else
            const Text('Зустрічі, події та спільні справи. Час — Київ.'),
          if (admin) ...[
            const SizedBox(height: 12),
            const Text(
              '1. Додайте локації в Керуванні. 2. Створіть подію. 3. Знайдіть її в цьому розкладі.',
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in viewChoices)
                item.$1 == view
                    ? FilledButton(
                        onPressed: () => navigate(focus, nextView: item.$1),
                        child: Text(item.$2),
                      )
                    : OutlinedButton(
                        onPressed: () => navigate(focus, nextView: item.$1),
                        child: Text(item.$2),
                      ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Попередній період',
                onPressed: () => navigate(
                  step == 0
                      ? DateTime(focus.year, focus.month - 1, 1)
                      : DateTime(focus.year, focus.month, focus.day - step),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                periodLabel(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                tooltip: 'Наступний період',
                onPressed: () => navigate(
                  step == 0
                      ? DateTime(focus.year, focus.month + 1, 1)
                      : DateTime(focus.year, focus.month, focus.day + step),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              OutlinedButton(
                onPressed: () =>
                    navigate(civil(TimeZoneService().toKyiv(DateTime.now()))),
                child: const Text('Сьогодні'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: focus,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (date != null && mounted) navigate(date, nextView: 'day');
                },
                child: const Text('Вибрати дату'),
              ),
              FilledButton(
                onPressed: () => book(signedIn, admin),
                child: const Text('Забронювати'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 720;
              final locationField = lockedRoom
                  ? InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Локація',
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lockedRoomName()!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => navigate(
                              focus,
                              room: null,
                              changeRoom: true,
                            ),
                            child: const Text('Усі локації'),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey('${widget.roomId}:${rooms.length}'),
                      initialValue: rooms.any((r) => r.id == widget.roomId)
                          ? widget.roomId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Локація'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Усі локації'),
                        ),
                        for (final room in rooms)
                          DropdownMenuItem(
                            value: room.id,
                            child: Text(
                              room.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          navigate(focus, room: value, changeRoom: true),
                    );
              final directionsField = InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Події за напрямками',
                ),
                child: InkWell(
                  onTap: busy
                      ? null
                      : () async {
                          final next = Set<String>.from(selectedDirections);
                          final applied = await showDialog<bool>(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setDialog) => AlertDialog(
                                title: const Text('Події за напрямками'),
                                content: SizedBox(
                                  width: 420,
                                  child: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        for (final direction in eventDirections)
                                          FilterChip(
                                            label: Text(direction),
                                            selected: next.contains(direction),
                                            onSelected: (selected) {
                                              setDialog(() {
                                                if (selected) {
                                                  next.add(direction);
                                                } else {
                                                  next.remove(direction);
                                                }
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      next.clear();
                                      Navigator.pop(context, true);
                                    },
                                    child: const Text('Усі напрямки'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Скасувати'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Застосувати'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (applied == true && mounted) {
                            setState(() {
                              selectedDirections
                                ..clear()
                                ..addAll(next);
                            });
                            load(reset: true);
                          }
                        },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDirections.isEmpty
                              ? 'Усі напрямки'
                              : 'Обрано: ${selectedDirections.length}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              );
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: locationField),
                    const SizedBox(width: 12),
                    Expanded(child: directionsField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  locationField,
                  const SizedBox(height: 12),
                  directionsField,
                ],
              );
            },
          ),
          if (widget.roomId != null &&
              rooms.isNotEmpty &&
              !rooms.any((r) => r.id == widget.roomId))
            const Text(
              'Фільтр локації заданий посиланням; її може бути архівовано.',
            ),
          if (roomNext != null && !lockedRoom)
            ActionButton(
              label: 'Завантажити ще локації',
              outlined: true,
              action: () async {
                final page = await ref
                    .read(repositoryProvider)
                    .listRooms(PageRequest(limit: 100, after: roomNext));
                if (mounted) {
                  setState(() {
                    rooms = [...rooms, ...page.items];
                    roomNext = page.next;
                  });
                }
              },
            ),
          const SizedBox(height: 20),
          if (invalidDate != null)
            Text(invalidDate!)
          else ...[
            if (error != null)
              Problem(error!, retry: () => load(reset: events.isEmpty)),
            if (busy) const LinearProgressIndicator(),
            if (!busy && error == null && events.isEmpty && next == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(switch (view) {
                  'day' => 'Цього дня подій немає.',
                  'week' => 'Цього тижня подій немає.',
                  _ => 'Цього місяця подій немає.',
                }),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= (isSchedule ? 720 : 760) &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.4;
                if (isSchedule) {
                  return ScheduleTable(
                    events: events,
                    wide: wide,
                    view: view,
                  );
                }
                return Column(
                  children: [
                    if (wide && view == 'month')
                      _MonthGrid(
                        month: DateTime(focus.year, focus.month),
                        events: events,
                        pagePath: widget.pagePath,
                      ),
                    if (wide && view == 'week')
                      _WeekGrid(focus: focus, events: events),
                    if (!wide || view == 'day' || view == 'list')
                      for (final event in events)
                        Card(
                          child: ListTile(
                            isThreeLine: true,
                            title: Text(
                              '${localDate(event.interval.start)} · ${localTime(event.interval.start)}–${localTime(event.interval.end)} · ${event.title}',
                            ),
                            subtitle: Text(
                              '${event.roomNameSnapshot}${event.responsibleName.isEmpty ? '' : ' · ${event.responsibleName}'}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go(
                              '/events/${Uri.encodeComponent(event.id)}',
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
            if (next != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: OutlinedButton(
                  onPressed: busy ? null : () => load(reset: false),
                  child: const Text('Завантажити ще події'),
                ),
              ),
            TextButton(
              onPressed: busy ? null : () => load(reset: true),
              child: Text(isSchedule ? 'Оновити розклад' : 'Оновити календар'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.events,
    required this.pagePath,
  });
  final DateTime month;
  final List<PublicEvent> events;
  final String pagePath;

  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final length = ((offset + days + 6) ~/ 7) * 7;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(day, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 112,
            ),
            itemCount: length,
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final start = tz.TZDateTime(
                    tz.getLocation('Europe/Kyiv'),
                    month.year,
                    month.month,
                    day,
                  ).toUtc(),
                  end = tz.TZDateTime(
                    tz.getLocation('Europe/Kyiv'),
                    month.year,
                    month.month,
                    day + 1,
                  ).toUtc();
              final todayEvents = events
                  .where(
                    (event) =>
                        event.interval.start.isBefore(end) &&
                        event.interval.end.isAfter(start),
                  )
                  .toList();
              return Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.go(
                        Uri(
                          path: pagePath,
                          queryParameters: {
                            ...GoRouterState.of(context).uri.queryParameters,
                            'date': DateFormat('yyyy-MM-dd')
                                .format(DateTime(month.year, month.month, day)),
                            'view': 'day',
                          },
                        ).toString(),
                      ),
                      child: _CalendarDayLabel(
                        DateTime(month.year, month.month, day),
                      ),
                    ),
                    for (final event in todayEvents.take(2))
                      InkWell(
                        onTap: () => context.go(
                          '/events/${Uri.encodeComponent(event.id)}',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${localTime(event.interval.start)} ${event.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _calendarEventStyle(
                              context,
                              DateTime(month.year, month.month, day),
                            ),
                          ),
                        ),
                      ),
                    if (todayEvents.length > 2)
                      Text(
                        '+${todayEvents.length - 2} — оберіть день',
                        style: _calendarEventStyle(
                          context,
                          DateTime(month.year, month.month, day),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

bool _isPastCalendarDay(DateTime day) {
  final now = tz.TZDateTime.now(tz.getLocation('Europe/Kyiv'));
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).isBefore(DateTime(now.year, now.month, now.day));
}

TextStyle? _calendarEventStyle(BuildContext context, DateTime day) {
  final past = _isPastCalendarDay(day);
  return Theme.of(context).textTheme.labelSmall?.copyWith(
    fontWeight: past ? FontWeight.w400 : FontWeight.w700,
    color: past ? Theme.of(context).colorScheme.outline : null,
  );
}

String eventWhenLabel(PublicEvent event) {
  final startDate = localDate(event.interval.start);
  final endDate = localDate(event.interval.end);
  final startTime = localTime(event.interval.start);
  final endTime = localTime(event.interval.end);
  if (startDate == endDate) {
    return '$startDate · $startTime–$endTime (Київ)';
  }
  return '$startDate · $startTime — $endDate $endTime (Київ)';
}

class _CalendarDayLabel extends StatelessWidget {
  const _CalendarDayLabel(this.day);
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = tz.TZDateTime.now(tz.getLocation('Europe/Kyiv'));
    final today =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: today
          ? BoxDecoration(color: colors.primary, shape: BoxShape.circle)
          : null,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: today
              ? colors.onPrimary
              : _isPastCalendarDay(day)
              ? colors.outline
              : colors.onSurface,
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.focus, required this.events});
  final DateTime focus;
  final List<PublicEvent> events;

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(
      focus.year,
      focus.month,
      focus.day - (focus.weekday - 1),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(child: _dayCell(context, monday, index)),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, DateTime monday, int index) {
    final day = DateTime(monday.year, monday.month, monday.day + index);
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
    final todayEvents = events
        .where(
          (event) =>
              event.interval.start.isBefore(end) &&
              event.interval.end.isAfter(start),
        )
        .toList();
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('E', 'uk').format(day),
                style: TextStyle(
                  color: _isPastCalendarDay(day)
                      ? Theme.of(context).colorScheme.outline
                      : null,
                ),
              ),
              _CalendarDayLabel(day),
            ],
          ),
          for (final event in todayEvents)
            InkWell(
              onTap: () =>
                  context.go('/events/${Uri.encodeComponent(event.id)}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${localTime(event.interval.start)} ${event.title}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _calendarEventStyle(context, day),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EventPage extends ConsumerStatefulWidget {
  const EventPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  late Future<PublicEvent?> event;
  @override
  void initState() {
    super.initState();
    event = ref.read(repositoryProvider).getPublishedEvent(widget.id);
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Подія',
    child: FutureBuilder(
      future: event,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Problem(
            snapshot.error!,
            retry: () => setState(
              () => event = ref
                  .read(repositoryProvider)
                  .getPublishedEvent(widget.id),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        final data = snapshot.data;
        if (data == null) {
          return const Text('Подію не знайдено або її скасовано.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(eventWhenLabel(data)),
            Text('${data.roomNameSnapshot} · ${data.locationSnapshot}'),
            if (data.responsibleName.isNotEmpty)
              Text('Відповідальний: ${data.responsibleName}'),
            const SizedBox(height: 24),
            SelectableText(data.description),
            if (data.contactPhone.isNotEmpty)
              SelectableText('Телефон: ${data.contactPhone}'),
            if (data.notes.isNotEmpty) Text('Примітки: ${data.notes}'),
            if (data.directions.isNotEmpty) Text(data.directions.join(' · ')),
            const SizedBox(height: 24),
            if (ref.watch(profileProvider).asData?.value?.role ==
                UserRole.admin)
              FilledButton.icon(
                onPressed: () => context.go('/bookings/${data.id}'),
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Керувати подією / Видалити'),
              ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('До календаря'),
            ),
          ],
        );
      },
    ),
  );
}

class RoomsPage extends ConsumerStatefulWidget {
  const RoomsPage({super.key});
  @override
  ConsumerState<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends ConsumerState<RoomsPage> {
  List<Room> rooms = [];
  PageCursor? next;
  Object? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await ref
          .read(repositoryProvider)
          .listRooms(PageRequest(after: next));
      if (mounted) {
        setState(() {
          rooms = [...rooms, ...page.items];
          next = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Локації',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) Problem(error!, retry: load),
        if (busy) const LinearProgressIndicator(),
        if (!busy && error == null && rooms.isEmpty)
          const Text('Локації ще не додані.'),
        for (final room in rooms)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(room.locationLabel),
                  if (room.capacity != null)
                    Text('Місткість: ${room.capacity}'),
                  const SizedBox(height: 8),
                  Text(room.description),
                  TextButton(
                    onPressed: () => context.go(
                      Uri(
                        path: '/schedule',
                        queryParameters: {'room': room.id},
                      ).toString(),
                    ),
                    child: const Text('Розклад локації'),
                  ),
                  TextButton(
                    onPressed: () => context.go(
                      Uri(
                        path: '/bookings/new',
                        queryParameters: {'room': room.id},
                      ).toString(),
                    ),
                    child: const Text('Забронювати'),
                  ),
                ],
              ),
            ),
          ),
        if (next != null)
          OutlinedButton(
            onPressed: busy ? null : load,
            child: const Text('Завантажити ще'),
          ),
      ],
    ),
  );
}
