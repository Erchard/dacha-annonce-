import '../../features/bookings/domain/event_details.dart';
import '../../features/bookings/data/booking_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/page.dart';
import '../../core/errors/domain_exception.dart';
import '../../core/time/booking_time.dart';
import '../../core/time/time_zone_service.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/bookings/domain/booking.dart';
import '../../features/bookings/domain/weekly_series.dart';
import '../../features/calendar/domain/public_event.dart';
import '../../features/rooms/domain/room.dart';
import '../providers.dart';
import 'shared.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.forAdmin = false});
  final bool forAdmin;
  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  List<Booking> items = [];
  PageCursor? next;
  BookingStatus? status;
  bool busy = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    status = null;
    Future.microtask(() => load(reset: true));
  }

  Future<void> load({required bool reset}) async {
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        items = [];
        next = null;
      }
    });
    try {
      final page = await ref
          .read(repositoryProvider)
          .listBookings(
            PageRequest(after: next),
            forAdmin: widget.forAdmin,
            status: status,
          );
      if (mounted) {
        setState(() {
          items = [...items, ...page.items];
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
    title: widget.forAdmin
        ? 'Керування подіями та заявками'
        : 'Мої події та заявки',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => context.go(
                widget.forAdmin ? '/admin/events/new' : '/bookings/new',
              ),
              child: Text(widget.forAdmin ? 'Створити подію' : 'Подати заявку'),
            ),
            if (widget.forAdmin) ...[
              OutlinedButton(
                onPressed: () => context.go('/admin/rooms'),
                child: const Text('Локації'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/admin/users'),
                child: const Text('Користувачі'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/support'),
                child: const Text('Написати розробнику'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<BookingStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Статус'),
          items: [
            const DropdownMenuItem<BookingStatus>(
              value: null,
              child: Text('Усі статуси'),
            ),
            for (final value in BookingStatus.values.where(
              (v) => v != BookingStatus.deleted,
            ))
              DropdownMenuItem(value: value, child: Text(statusLabel(value))),
          ],
          onChanged: busy
              ? null
              : (value) {
                  setState(() => status = value);
                  load(reset: true);
                },
        ),
        const SizedBox(height: 16),
        if (error != null)
          Problem(error!, retry: () => load(reset: items.isEmpty)),
        if (busy) const LinearProgressIndicator(),
        if (!busy && error == null && items.isEmpty && next == null)
          Text(
            widget.forAdmin ? 'Заявок із цим статусом немає.' : 'Немає заявок від сьогодні. Минулі події в цьому списку не показуються.',
          ),
        if (items.isNotEmpty)
          Text(
            widget.forAdmin
                ? 'Завантажено заявок: ${items.length}${next != null ? ' · доступні наступні сторінки' : ''}'
                : 'Від сьогодні за календарем: ${items.length}${next != null ? ' · є наступні' : ''}',
          ),
        for (final booking in items)
          Card(
            child: ListTile(
              title: Text(booking.draft.title),
              subtitle: Text(
                '${statusLabel(booking.status)}\n${localDate(booking.draft.interval.start)} · ${localTime(booking.draft.interval.start)}–${localTime(booking.draft.interval.end)}${booking.draft.responsibleName.isEmpty ? '' : '\n${booking.draft.responsibleName}'}',
              ),
              isThreeLine: true,
              onTap: () => context.go('/bookings/${booking.id}'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        if (next != null)
          OutlinedButton(
            onPressed: busy ? null : () => load(reset: false),
            child: const Text('Завантажити ще'),
          ),
        TextButton(
          onPressed: busy ? null : () => load(reset: true),
          child: const Text('Оновити список'),
        ),
      ],
    ),
  );
}

class BookingFormPage extends ConsumerStatefulWidget {
  const BookingFormPage({
    super.key,
    this.id,
    this.approved = false,
    this.initialRoomId,
  });
  final String? id;
  final bool approved;
  final String? initialRoomId;
  @override
  ConsumerState<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends ConsumerState<BookingFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      responsible = TextEditingController(),
      contactPhone = TextEditingController(),
      notes = TextEditingController(),
      date = TextEditingController(),
      start = TextEditingController(text: '10:00'),
      end = TextEditingController(text: '11:00'),
      until = TextEditingController();
  late String id;
  String? seriesToken;
  bool weekly = false;
  List<String> directions = [];
  Booking? original;
  List<Room> rooms = [];
  String? roomId, message;
  PageCursor? roomNext;
  Object? loadError;
  bool loading = true, busy = false;
  @override
  void initState() {
    super.initState();
    id = widget.id ?? ref.read(bookingServiceProvider).newId();
    final kyiv = TimeZoneService().toKyiv(DateTime.now());
    date.text = formatCivilDate(DateTime(kyiv.year, kyiv.month, kyiv.day + 1));
    applyDefaultTimesForSelectedDay();
    Future.microtask(load);
  }

  DateTime? civilDate() => parseCivilDate(date.text);

  String slotLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Next half-hour in Kyiv that is still in the future for [day], or null if none.
  (int, int)? nextFutureSlot(DateTime day) {
    final now = TimeZoneService().toKyiv(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    var hour = 10;
    var minute = 0;
    if (day == today) {
      hour = now.hour;
      minute = now.minute < 30 ? 30 : 0;
      if (now.minute >= 30) hour += 1;
      if (hour >= 24) return null;
    } else if (day.isBefore(today)) {
      return null;
    }
    return (hour, minute);
  }

  void applyDefaultTimesForSelectedDay() {
    final day = civilDate();
    if (day == null) return;
    if (chosenStartStillValid(day)) return;
    final slot = nextFutureSlot(day);
    if (slot == null) {
      start.text = '10:00';
      end.text = '11:00';
      return;
    }
    final (hour, minute) = slot;
    start.text = slotLabel(hour, minute);
    final endMinute = minute;
    final endHour = hour + 1;
    end.text = endHour < 24 ? slotLabel(endHour, endMinute) : slotLabel(23, 30);
  }

  bool chosenStartStillValid(DateTime day) {
    final parts = start.text.split(':');
    if (parts.length != 2) return false;
    final hour = int.tryParse(parts[0]), minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;
    final candidates = TimeZoneService().candidates(
      year: day.year,
      month: day.month,
      day: day.day,
      hour: hour,
      minute: minute,
    );
    return candidates.isNotEmpty &&
        candidates.first.isAfter(DateTime.now().toUtc());
  }

  Future<void> pickClock(TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 10,
      minute: int.tryParse(parts.length < 2 ? '' : parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final minute = picked.minute < 15
        ? 0
        : picked.minute < 45
        ? 30
        : 0;
    final hour = picked.minute >= 45 ? (picked.hour + 1) % 24 : picked.hour;
    setState(() => controller.text = slotLabel(hour, minute));
  }

  @override
  void dispose() {
    for (final c in [
      title,
      description,
      responsible,
      contactPhone,
      notes,
      date,
      start,
      end,
      until,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final page = await repo.listRooms(PageRequest(limit: 100));
      final booking = widget.id == null
          ? null
          : await repo.getBooking(widget.id!);
      if (widget.id != null && booking == null) {
        throw const DomainException(ErrorCode.notFound);
      }
      if (booking != null &&
          (booking.status != BookingStatus.pending &&
              (booking.status != BookingStatus.approved ||
                  (ref.read(profileProvider).asData?.value?.role !=
                          UserRole.admin &&
                      ref.read(profileProvider).asData?.value?.canPublish !=
                          true)))) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      final list = page.items.toList();
      if (booking != null && !list.any((r) => r.id == booking.draft.roomId)) {
        final oldRoom = await repo.getRoom(booking.draft.roomId);
        if (oldRoom != null) list.add(oldRoom);
      }
      if (mounted) {
        setState(() {
          rooms = list;
          roomNext = page.next;
          original = booking;
          if (booking != null) {
            roomId = booking.draft.roomId;
            title.text = booking.draft.title;
            description.text = booking.draft.description;
            responsible.text = booking.draft.responsibleName;
            contactPhone.text = booking.draft.contactPhone;
            notes.text = booking.draft.notes;
            directions = [...booking.draft.directions];
            final local = TimeZoneService().toKyiv(
              booking.draft.interval.start,
            );
            date.text = formatCivilDate(local);
            start.text = localTime(booking.draft.interval.start);
            end.text = localTime(booking.draft.interval.end);
          } else {
            roomId = rooms.any((room) => room.id == widget.initialRoomId)
                ? widget.initialRoomId
                : rooms.firstOrNull?.id;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadError = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<DateTime?> instant(DateTime day, String text) async {
    final parts = text.split(':');
    final candidates = TimeZoneService().candidates(
      year: day.year,
      month: day.month,
      day: day.day,
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    if (candidates.isEmpty) {
      setState(
        () => message = 'Цього часу не існує через переведення годинника. Виберіть інший час.',
      );
      return null;
    }
    if (candidates.length == 1) return candidates.single;
    return showDialog<DateTime>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('$text трапляється двічі. Оберіть варіант:'),
        children: [
          for (final value in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(
                '$text · UTC${TimeZoneService().toKyiv(value).timeZoneOffset.inHours >= 0 ? '+' : ''}${TimeZoneService().toKyiv(value).timeZoneOffset.inHours}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final day = civilDate();
      if (day == null) {
        setState(() => message = 'Перевірте дату.');
        return;
      }
      if (!chosenStartStillValid(day)) {
        setState(
          () => message = 'Початок має бути пізніше за поточний час (Київ). Введений час не змінюється сам — оберіть пізніший.',
        );
        return;
      }
      final first = await instant(day, start.text);
      if (first == null) return;
      // An end time earlier than or equal to the start denotes the next calendar day.
      final nextDay = end.text.compareTo(start.text) <= 0
          ? DateTime(day.year, day.month, day.day + 1)
          : day;
      final last = await instant(nextDay, end.text);
      if (last == null) return;
      final draft = BookingDraft(
        roomId: roomId!,
        title: title.text,
        description: description.text,
        responsibleName: responsible.text,
        contactPhone: contactPhone.text,
        notes: notes.text,
        directions: directions,
        interval: BookingInterval(first, last),
      );
      if (weekly &&
          (widget.approved ||
              ref.read(profileProvider).asData?.value?.canPublish == true) &&
          original == null) {
        await submitWeekly(draft);
        return;
      }
      final profile = ref.read(profileProvider).asData!.value!;
      BookingAction action;
      if (original == null) {
        action =
            (widget.approved ||
                    ref.read(profileProvider).asData?.value?.canPublish ==
                        true) &&
                (profile.role == UserRole.admin || profile.canPublish)
            ? BookingAction.createApproved
            : BookingAction.createPending;
      } else if (original!.status == BookingStatus.approved &&
          (draft.roomId != original!.draft.roomId ||
              first != original!.draft.interval.start ||
              last != original!.draft.interval.end)) {
        action = BookingAction.reschedule;
      } else {
        action = BookingAction.edit;
      }
      if (action == BookingAction.createPending ||
          original?.status == BookingStatus.pending &&
              action == BookingAction.edit) {
        final possible = await ref
            .read(repositoryProvider)
            .listRange(first, last, PageRequest(limit: 100), roomId: roomId);
        if (possible.items.any(
          (event) => event.id != id && event.interval.overlaps(draft.interval),
        )) {
          if (!mounted) return;
          if (!await confirmAction(
            context,
            'Цей час уже зайнятий',
            'Можна подати заявку на розгляд, але вона не резервує кімнату. Адміністрація має узгодити інший час. Подати заявку?',
          )) {
            return;
          }
        }
      }
      await ref
          .read(bookingServiceProvider)
          .execute(
            id,
            action,
            expectedVersion: original?.version ?? 0,
            draft: draft,
          );
      if (mounted) context.go('/bookings/$id');
    } catch (e) {
      if (mounted) setState(() => message = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<List<PublicEvent>> eventsBetween(
    DateTime start,
    DateTime end,
    String room,
  ) async {
    final events = <PublicEvent>[];
    var cursor = start.toUtc();
    final limit = end.toUtc();
    while (cursor.isBefore(limit)) {
      final chunkEnd = cursor.add(const Duration(days: 60)).isAfter(limit)
          ? limit
          : cursor.add(const Duration(days: 60));
      PageCursor? page;
      do {
        final result = await ref
            .read(repositoryProvider)
            .listRange(
              cursor,
              chunkEnd,
              PageRequest(limit: 100, after: page),
              roomId: room,
            );
        events.addAll(result.items);
        page = result.next;
      } while (page != null);
      cursor = chunkEnd;
    }
    return events;
  }

  bool sameSeriesBooking(Booking existing, WeekDate date, BookingDraft draft) =>
      existing.draft.roomId == draft.roomId &&
      existing.draft.title == draft.title &&
      existing.draft.description == draft.description &&
      existing.draft.responsibleName == draft.responsibleName &&
      existing.draft.contactPhone == draft.contactPhone &&
      existing.draft.notes == draft.notes &&
      existing.draft.directions.join("|") == draft.directions.join("|") &&
      existing.draft.interval.start == date.interval!.start &&
      existing.draft.interval.end == date.interval!.end;

  Future<void> submitWeekly(BookingDraft draft) async {
    final untilDay = parseCivilDate(until.text);
    if (untilDay == null) {
      setState(() => message = 'Перевірте дату завершення повторення.');
      return;
    }
    final dates = weeklyDates(
      start: draft.interval.start,
      end: draft.interval.end,
      until: untilDay,
    );
    final notes = <String>[];
    final ready = <WeekDate>[];
    for (final date in dates) {
      if (date.problem != null) {
        notes.add('${date.label}: ${date.problem}');
        continue;
      }
      try {
        date.interval!.validateFuture(const SystemClock());
        ready.add(date);
      } on DomainException {
        notes.add(
          '${date.label}: подія має починатися в майбутньому і не пізніше ніж за 180 днів.',
        );
      }
    }
    if (notes.isNotEmpty || ready.isEmpty) {
      setState(() => message = notes.join('\n'));
      return;
    }
    seriesToken ??= ref.read(bookingServiceProvider).newId();
    final token = seriesToken!;
    final published = await eventsBetween(
      ready.first.interval!.start,
      ready.last.interval!.end,
      draft.roomId,
    );
    final conflicts = <String>[];
    for (final date in ready) {
      final id = '$token-${date.key}';
      final hit = published.where(
        (event) => event.id != id && event.interval.overlaps(date.interval!),
      );
      if (hit.isNotEmpty) {
        conflicts.add('${date.label}: зайнято «${hit.first.title}»');
      }
    }
    if (!mounted) return;
    final lines = [
      for (final date in ready)
        conflicts.where((line) => line.startsWith(date.label)).firstOrNull ??
            '${date.label} · ${localTime(date.interval!.start)}–${localTime(date.interval!.end)} · вільно',
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          conflicts.isEmpty
              ? 'Створити ${ready.length} подій?'
              : 'Є зайняті дати',
        ),
        content: SingleChildScrollView(child: Text(lines.join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          if (conflicts.isEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Створити'),
            ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final created = <String>[];
    for (var index = 0; index < ready.length; index++) {
      final date = ready[index];
      final occurrenceId = '$token-${date.key}';
      try {
        final existing = await ref
            .read(repositoryProvider)
            .getBooking(occurrenceId);
        if (existing != null) {
          if (!sameSeriesBooking(existing, date, draft)) {
            setState(
              () => message =
                  'Подію ${date.label} уже створено з іншими даними. Її не перезаписано.\nСтворені дати: ${created.join(', ')}',
            );
            return;
          }
          created.add(date.label);
          continue;
        }
        await ref
            .read(bookingServiceProvider)
            .execute(
              occurrenceId,
              BookingAction.createApproved,
              expectedVersion: 0,
              draft: BookingDraft(
                roomId: draft.roomId,
                title: draft.title,
                description: draft.description,
                responsibleName: draft.responsibleName,
                contactPhone: draft.contactPhone,
                notes: draft.notes,
                directions: draft.directions,
                interval: date.interval!,
              ),
            );
        created.add(date.label);
      } catch (error) {
        final rest = ready.skip(index + 1).map((item) => item.label).join(', ');
        setState(
          () => message =
              'Створено: ${created.join(', ')}\nНе створено ${date.label}: ${errorMessage(error)}${rest.isEmpty ? '' : '\nНе починались: $rest'}\nПовтор не дублює вже створені дати.',
        );
        return;
      }
    }
    if (mounted) {
      context.go(
        Uri(
          path: '/',
          queryParameters: {
            'date': ready.first.label,
            'view': 'list',
            'room': draft.roomId,
          },
        ).toString(),
      );
    }
  }

  String? timeValidator(String? value) {
    if (value == null ||
        !RegExp(r'^(?:[01][0-9]|2[0-3]):(?:00|30)$').hasMatch(value)) {
      return 'Час у форматі ГГ:00 або ГГ:30.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).asData?.value,
        session = ref.watch(sessionProvider).asData?.value;
    if (user?.role == UserRole.organizer && session?.emailVerified != true) {
      return AppFrame(
        title: 'Підтвердьте електронну адресу',
        child: FilledButton(
          onPressed: () => context.go('/account'),
          child: const Text('Перейти до підтвердження'),
        ),
      );
    }
    return AppFrame(
      title: original != null
          ? 'Редагувати заявку'
          : (widget.approved ||
                ref.read(profileProvider).asData?.value?.canPublish == true)
          ? 'Створити подію'
          : 'Подати заявку',
      child: loading
          ? const LinearProgressIndicator()
          : loadError != null
          ? Problem(loadError!, retry: load)
          : rooms.isEmpty
          ? const Text('Поки немає доступних локацій. Додайте їх у Керуванні.')
          : Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Назва, опис і відповідальний будуть публічними після схвалення. Не додавайте контакти або конфіденційні відомості.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Назва події'),
                    maxLength: 120,
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'Укажіть назву від 3 символів.'
                        : null,
                  ),
                  TextFormField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Опис'),
                    maxLines: 4,
                    maxLength: 5000,
                  ),
                  TextFormField(
                    controller: responsible,
                    decoration: const InputDecoration(
                      labelText: 'Відповідальний (необов’язково)',
                    ),
                    maxLength: 80,
                    validator: (value) => (value?.trim().runes.length ?? 0) > 80
                        ? 'До 80 символів.'
                        : null,
                  ),
                  TextFormField(
                    controller: contactPhone,
                    keyboardType: TextInputType.phone,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Телефон відповідального',
                      helperText:
                          'Необов’язково. Буде видимий відвідувачам сайту.',
                      helperMaxLines: 2,
                    ),
                    validator: (value) {
                      try {
                        checkedContactPhone(value ?? '');
                        return null;
                      } on DomainException {
                        return 'Укажіть телефон: цифри, +, пробіли, дужки або дефіси.';
                      }
                    },
                  ),
                  TextFormField(
                    controller: notes,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Примітки до розкладу',
                      hintText: 'Що взяти із собою, умови участі…',
                    ),
                  ),
                  const Text('Напрямки події — можна вибрати кілька'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final direction in eventDirections)
                        FilterChip(
                          label: Text(direction),
                          selected: directions.contains(direction),
                          onSelected: busy
                              ? null
                              : (selected) => setState(() {
                                  if (selected) {
                                    directions.add(direction);
                                  } else {
                                    directions.remove(direction);
                                  }
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('$roomId:${rooms.length}'),
                    initialValue: roomId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Локація'),
                    items: [
                      for (final room in rooms)
                        DropdownMenuItem(
                          value: room.id,
                          child: Text(
                            '${room.name}${room.isActive ? '' : ' (архів)'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => roomId = value),
                    validator: (v) => v == null ? 'Оберіть кімнату.' : null,
                  ),
                  if (roomNext != null)
                    ActionButton(
                      label: 'Завантажити ще кімнати',
                      outlined: true,
                      action: () async {
                        final page = await ref
                            .read(repositoryProvider)
                            .listRooms(
                              PageRequest(limit: 100, after: roomNext),
                            );
                        if (mounted) {
                          setState(() {
                            rooms = [
                              ...rooms,
                              ...page.items.where(
                                (r) => !rooms.any((old) => old.id == r.id),
                              ),
                            ];
                            roomNext = page.next;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата (ДД.ММ.РРРР)',
                      suffixIcon: IconButton(
                        tooltip: 'Вибрати дату',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final initial =
                              civilDate() ??
                              TimeZoneService().toKyiv(DateTime.now());
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null && mounted) {
                            setState(() {
                              date.text = formatCivilDate(selected);
                              applyDefaultTimesForSelectedDay();
                            });
                          }
                        },
                      ),
                    ),
                    onChanged: (_) => setState(applyDefaultTimesForSelectedDay),
                    validator: (v) => parseCivilDate(v ?? '') == null
                        ? 'Дата у форматі ДД.ММ.РРРР, наприклад 02.10.2026.'
                        : null,
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: start,
                          decoration: InputDecoration(
                            labelText: 'Початок (Київ)',
                            suffixIcon: IconButton(
                              tooltip: 'Вибрати початок',
                              icon: const Icon(Icons.schedule),
                              onPressed: busy ? null : () => pickClock(start),
                            ),
                          ),
                          validator: timeValidator,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextFormField(
                          controller: end,
                          decoration: InputDecoration(
                            labelText: 'Завершення (Київ)',
                            suffixIcon: IconButton(
                              tooltip: 'Вибрати завершення',
                              icon: const Icon(Icons.schedule),
                              onPressed: busy ? null : () => pickClock(end),
                            ),
                          ),
                          validator: timeValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Крок — 30 хвилин. Тривалість — до 6 годин. Для сьогодні час початку й завершення має бути пізніше за зараз. Раніший час завершення означає наступний день.',
                  ),
                  if ((widget.approved ||
                          ref.read(profileProvider).asData?.value?.canPublish ==
                              true) &&
                      original == null) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Повторювати щотижня до дати'),
                      value: weekly,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => weekly = value),
                    ),
                    if (weekly)
                      TextFormField(
                        controller: until,
                        decoration: InputDecoration(
                          labelText: 'Повторювати до (ДД.ММ.РРРР)',
                          suffixIcon: IconButton(
                            tooltip: 'Вибрати дату завершення',
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final initial =
                                  parseCivilDate(until.text) ??
                                  parseCivilDate(date.text) ??
                                  DateTime.now();
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (selected != null) {
                                until.text = formatCivilDate(selected);
                              }
                            },
                          ),
                        ),
                        validator: (value) {
                          if (!weekly) return null;
                          return parseCivilDate(value ?? '') == null
                              ? 'Дата у форматі ДД.ММ.РРРР.'
                              : null;
                        },
                      ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Зберігаємо…'
                          : original == null
                          ? 'Надіслати'
                          : 'Зберегти зміни',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => context.go(
                            original == null ? '/my-bookings' : '/bookings/$id',
                          ),
                    child: const Text('Назад'),
                  ),
                ],
              ),
            ),
    );
  }
}

class BookingDetailPage extends ConsumerStatefulWidget {
  const BookingDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends ConsumerState<BookingDetailPage> {
  late Future<Booking?> request;
  @override
  void initState() {
    super.initState();
    request = ref.read(repositoryProvider).getBooking(widget.id);
  }

  void reload() => setState(
    () => request = ref.read(repositoryProvider).getBooking(widget.id),
  );
  Future<String?> reasonDialog({required bool reject}) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reject ? 'Причина відхилення' : 'Скасувати бронювання?'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: reject ? 'Причина' : 'Причина (необов’язково)',
            ),
            maxLength: 1000,
            maxLines: 3,
            validator: (value) => reject && (value?.trim().length ?? 0) < 3
                ? 'Укажіть причину від 3 символів.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(reject ? 'Відхилити' : 'Скасувати бронювання'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).asData?.value;
    final admin = profile?.role == UserRole.admin;
    final publisher =
        profile?.role == UserRole.organizer && profile?.canPublish == true;
    return AppFrame(
      title: 'Заявка',
      child: FutureBuilder(
        future: request,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Problem(snapshot.error!, retry: reload);
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          final booking = snapshot.data;
          if (booking == null) return const Text('Заявку не знайдено.');
          final active =
              booking.status == BookingStatus.pending ||
              booking.status == BookingStatus.approved;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.draft.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Chip(label: Text(statusLabel(booking.status))),
              if (booking.roomNameSnapshot.isNotEmpty)
                Text('Локація: ${booking.roomNameSnapshot}')
              else
                FutureBuilder(
                  future: ref
                      .read(repositoryProvider)
                      .getRoom(booking.draft.roomId),
                  builder: (context, snapshot) => snapshot.hasError
                      ? Problem(snapshot.error!)
                      : Text(
                          snapshot.hasData
                              ? 'Локація: ${snapshot.data!.name}'
                              : 'Локація: ${booking.draft.roomId}',
                        ),
                ),
              if (booking.draft.responsibleName.isNotEmpty)
                Text('Відповідальний: ${booking.draft.responsibleName}'),
              Text(
                '${localDate(booking.draft.interval.start)} · ${localTime(booking.draft.interval.start)} — ${localDate(booking.draft.interval.end)} ${localTime(booking.draft.interval.end)} (Київ)',
              ),
              const SizedBox(height: 16),
              SelectableText(booking.draft.description),
              if (booking.rejectionReason != null)
                Text('Причина відхилення: ${booking.rejectionReason}'),
              if (booking.cancellationReason?.isNotEmpty == true)
                Text('Причина скасування: ${booking.cancellationReason}'),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (admin && booking.status == BookingStatus.pending) ...[
                    ActionButton(
                      label: 'Схвалити',
                      action: () async {
                        await ref
                            .read(bookingServiceProvider)
                            .execute(
                              booking.id,
                              BookingAction.approve,
                              expectedVersion: booking.version,
                            );
                        if (mounted) reload();
                      },
                    ),
                    ActionButton(
                      label: 'Відхилити',
                      outlined: true,
                      action: () async {
                        final reason = await reasonDialog(reject: true);
                        if (reason == null) return;
                        await ref
                            .read(bookingServiceProvider)
                            .execute(
                              booking.id,
                              BookingAction.reject,
                              expectedVersion: booking.version,
                              reason: reason,
                            );
                        if (mounted) reload();
                      },
                    ),
                  ],
                  if (active &&
                      (admin ||
                          publisher ||
                          booking.status == BookingStatus.pending))
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/bookings/${booking.id}/edit'),
                      child: const Text('Редагувати'),
                    ),
                  if (active &&
                      (admin ||
                          booking.draft.interval.start.isAfter(
                            DateTime.now().toUtc(),
                          )))
                    ActionButton(
                      label: 'Скасувати',
                      outlined: true,
                      action: () async {
                        final reason = await reasonDialog(reject: false);
                        if (reason == null) return;
                        await ref
                            .read(bookingServiceProvider)
                            .execute(
                              booking.id,
                              BookingAction.cancel,
                              expectedVersion: booking.version,
                              reason: reason.isEmpty ? null : reason,
                            );
                        if (mounted) reload();
                      },
                    ),
                  if (booking.status == BookingStatus.approved)
                    OutlinedButton(
                      onPressed: () => context.go('/events/${booking.id}'),
                      child: const Text('Публічна подія'),
                    ),
                  if (admin || publisher)
                    ActionButton(
                      label: 'Видалити',
                      outlined: true,
                      action: () async {
                        if (!await confirmAction(
                          context,
                          'Видалити подію?',
                          'Подія зникне з календаря й заявок, а час стане вільним. Відновлення не передбачено. Технічна історія дій зберігається. Для відміни запланованої зустрічі використовуйте «Скасувати».',
                        )) {
                          return;
                        }
                        await ref
                            .read(bookingServiceProvider)
                            .execute(
                              booking.id,
                              BookingAction.delete,
                              expectedVersion: booking.version,
                            );
                        if (context.mounted) {
                          context.go(admin ? '/admin' : '/my-bookings');
                        }
                      },
                    ),
                  if ((admin || publisher) &&
                      BookingService.seriesPrefix(booking.id) != null)
                    ActionButton(
                      label: 'Видалити всю серію',
                      outlined: true,
                      action: () async {
                        final service = ref.read(bookingServiceProvider);
                        final occurrences = await service.seriesOccurrences(
                          booking.id,
                        );
                        if (!context.mounted) return;
                        if (!await confirmAction(
                          context,
                          'Видалити всю серію?',
                          'Буде видалено подій: ${occurrences.length}. Включно зі скасованими та минулими входженнями цієї серії. Відновлення не передбачено.',
                        )) {
                          return;
                        }
                        // Keep this page available if a later transaction fails; retry skips already deleted occurrences.
                        final ordered = [
                          ...occurrences.where((b) => b.id != booking.id),
                          ...occurrences.where((b) => b.id == booking.id),
                        ];
                        var completed = 0;
                        try {
                          for (final occurrence in ordered) {
                            await service.execute(
                              occurrence.id,
                              BookingAction.delete,
                              expectedVersion: occurrence.version,
                            );
                            completed++;
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Видалено $completed із ${ordered.length}. ${errorMessage(error)} Натисніть «Видалити всю серію» ще раз для решти.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        if (context.mounted) {
                          context.go(admin ? '/admin' : '/my-bookings');
                        }
                      },
                    ),
                  TextButton(onPressed: reload, child: const Text('Оновити')),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(admin ? '/admin' : '/my-bookings'),
                child: const Text('До списку заявок'),
              ),
            ],
          );
        },
      ),
    );
  }
}
