import 'package:dacha_annonce/app/app.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/domain/page.dart' as paging;
import 'package:dacha_annonce/core/time/booking_time.dart';
import 'package:dacha_annonce/core/time/time_zone_service.dart';
import 'package:dacha_annonce/core/errors/domain_exception.dart';
import 'package:dacha_annonce/features/calendar/data/public_event_dto.dart';
import 'package:dacha_annonce/features/calendar/domain/public_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show EmptyRepository;

PublicEvent sample(String id, int hour, {String phone = '+380 00 000 00 00'}) =>
    PublicEvent(
      id: id,
      title: 'Зустріч $id',
      description: 'Опис',
      roomId: 'room',
      roomNameSnapshot: 'Мала вітальня',
      locationSnapshot: 'Дача',
      responsibleName: 'Відповідальна особа',
      contactPhone: phone,
      notes: 'Взяти смаколики до чаю та блокнот для нотаток',
      directions: ['Культура', 'Для дітей'],
      interval: BookingInterval(
        DateTime.utc(2026, 10, 20, hour),
        DateTime.utc(2026, 10, 20, hour + 1),
      ),
      bookingVersion: 1,
      publishedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class ScheduleRepository extends EmptyRepository {
  DateTime? from, to;
  List<String> filters = [];
  @override
  Future<paging.Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    paging.PageRequest page, {
    String? roomId,
    List<String> directions = const [],
  }) async {
    from = start;
    to = end;
    filters = directions;
    return paging.Page([sample('друга', 12), sample('перша', 10)], null);
  }
}

void main() {
  test('schedule data reads legacy records and rejects invalid new data', () {
    final data = PublicEventDto.encode(sample('test', 10));
    final legacy = {...data}
      ..remove('contactPhone')
      ..remove('notes')
      ..remove('directions');
    expect(PublicEventDto.decode('old', legacy).contactPhone, '');
    expect(PublicEventDto.decode('old', legacy).directions, isEmpty);
    expect(PublicEventDto.encode(PublicEventDto.decode('new', data)), data);
    for (final patch in [
      <String, dynamic>{
        'directions': ['Клуб', 'Клуб'],
      },
      {
        'directions': ['Невідомий'],
      },
      {
        'directions': [12],
      },
      {'contactPhone': null},
      {'notes': 12},
    ]) {
      expect(
        () => PublicEventDto.decode('bad', {...data, ...patch}),
        throwsA(isA<DomainException>()),
      );
    }
  });

  for (final width in [1200.0, 320.0]) {
    testWidgets(
      'schedule poster shows columns, brand header and day/week at $width',
      (tester) async {
        TimeZoneService();
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ScheduleRepository();
        final router = createRouter(
          initialLocation: '/schedule?date=2026-10-20&view=week',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              sessionProvider.overrideWith((ref) => Stream.value(null)),
              profileProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: DachaApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Тиждень на Дачі'), findsOneWidget);
        expect(find.textContaining('Взяти смаколики'), findsNWidgets(2));
        expect(find.text('+380 00 000 00 00'), findsNWidgets(2));
        expect(find.text('Місяць'), findsOneWidget);
        expect(find.text('Події за напрямками'), findsOneWidget);
        expect(find.text('Усі напрямки'), findsOneWidget);
        if (width > 720) {
          expect(find.textContaining('Відповідальний'), findsWidgets);
          expect(find.text('Примітки'), findsOneWidget);
          expect(find.text('Назва події'), findsOneWidget);
        }
        expect(
          tester.getTopLeft(find.text('Зустріч перша')).dy,
          lessThan(tester.getTopLeft(find.text('Зустріч друга')).dy),
        );
        final zone = TimeZoneService();
        expect(zone.toKyiv(repo.from!).day, 19);
        expect(zone.toKyiv(repo.to!).day, 26);
        await tester.ensureVisible(find.text('День'));
        await tester.tap(find.text('День'));
        await tester.pumpAndSettle();
        expect(find.text('Зустрічаємося на Дачі'), findsOneWidget);
        expect(find.textContaining('2 події'), findsOneWidget);
        expect(zone.toKyiv(repo.from!).day, 20);
        expect(zone.toKyiv(repo.to!).day, 21);
        await tester.ensureVisible(find.text('Місяць'));
        await tester.tap(find.text('Місяць'));
        await tester.pumpAndSettle();
        expect(find.text('Місяць на Дачі'), findsOneWidget);
        expect(zone.toKyiv(repo.from!).day, 1);
        expect(zone.toKyiv(repo.to!).day, 1);
        expect(zone.toKyiv(repo.to!).month, 11);
        await tester.ensureVisible(find.text('Сьогодні'));
        await tester.tap(find.text('Сьогодні'));
        await tester.pumpAndSettle();
        expect(
          zone.toKyiv(repo.from!).month,
          zone.toKyiv(DateTime.now()).month,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('home shows month calendar grid', (tester) async {
    TimeZoneService();
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(initialLocation: '/');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(ScheduleRepository()),
          sessionProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: DachaApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('Зустрічі, події та спільні справи. Час — Київ.'), findsOneWidget);
    expect(find.text('Тиждень на Дачі'), findsNothing);
    expect(find.text('Пн'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Календар'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Розклад'), findsWidgets);
  });

  testWidgets('/calendar shows week grid', (tester) async {
    TimeZoneService();
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(initialLocation: '/calendar?view=week');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(ScheduleRepository()),
          sessionProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: DachaApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/calendar');
    expect(find.text('Тиждень на Дачі'), findsNothing);
    expect(find.text('Зустрічі, події та спільні справи. Час — Київ.'), findsOneWidget);
  });

  testWidgets('schedule shows contact fallback without phone', (tester) async {
    TimeZoneService();
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = createRouter(
      initialLocation: '/schedule?date=2026-10-20&view=day',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            _NoPhoneRepository(),
          ),
          sessionProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: DachaApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Контакт уточнюється'), findsOneWidget);
  });
}

class _NoPhoneRepository extends EmptyRepository {
  @override
  Future<paging.Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    paging.PageRequest page, {
    String? roomId,
    List<String> directions = const [],
  }) async =>
      paging.Page([sample('alone', 10, phone: '')], null);
}
