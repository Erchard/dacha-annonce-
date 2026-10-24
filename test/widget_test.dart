import 'package:dacha_annonce/core/time/booking_time.dart';
import 'package:dacha_annonce/app/app.dart';
import 'package:dacha_annonce/app/data/app_repository.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/domain/page.dart' as paging;
import 'package:dacha_annonce/features/calendar/domain/public_event.dart';
import 'package:dacha_annonce/features/rooms/domain/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class EmptyRepository implements AppRepository {
  @override
  Future<paging.Page<Room>> listRooms(
    paging.PageRequest page, {
    bool activeOnly = true,
  }) async => paging.Page([], null);
  @override
  Future<paging.Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    paging.PageRequest page, {
    String? roomId,
    List<String> directions = const [],
  }) async => paging.Page([], null);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class PopulatedRepository extends EmptyRepository {
  @override
  Future<paging.Page<PublicEvent>> listRange(
    DateTime start,
    DateTime end,
    paging.PageRequest page, {
    String? roomId,
    List<String> directions = const [],
  }) async {
    final date = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      15,
      10,
    );
    return paging.Page([
      PublicEvent(
        id: 'sample',
        title: 'Спільна зустріч для обговорення планів і підготовки заходів на Дачі',
        description: 'Опис',
        roomId: 'room',
        roomNameSnapshot: 'Велика кімната для спільних зустрічей',
        locationSnapshot: 'Дача',
        responsibleName: '',
        interval: BookingInterval(date, date.add(const Duration(hours: 1))),
        bookingVersion: 1,
        publishedAt: date,
        updatedAt: date,
      ),
    ], null);
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    String route, {
    bool populated = false,
  }) async {
    final router = createRouter(initialLocation: route);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            populated ? PopulatedRepository() : EmptyRepository(),
          ),
          sessionProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: DachaApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Public calendar renders an honest empty state', (tester) async {
    await open(tester, '/');
    expect(find.text('Зустрічі, події та спільні справи. Час — Київ.'), findsOneWidget);
    expect(find.text('Календар'), findsWidgets);
    expect(find.text('Тиждень на Дачі'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Unknown deep link can return to calendar', (tester) async {
    await open(tester, '/missing');
    expect(find.text('Сторінку не знайдено'), findsOneWidget);
    await tester.tap(find.text('На головну'));
    await tester.pumpAndSettle();
    expect(find.text('Зустрічі, події та спільні справи. Час — Київ.'), findsOneWidget);
  });
  testWidgets(
    'Private deep link requires sign-in without reading private data',
    (tester) async {
      await open(tester, '/admin');
      expect(find.text('Потрібен вхід'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Register and password reset have appropriate fields', (
    tester,
  ) async {
    await open(tester, '/reset-password');
    expect(find.text('Пароль'), findsNothing);
    expect(find.text('Електронна адреса'), findsOneWidget);
  });
  testWidgets('Startup explicitly reports loading and errors', (tester) async {
    await tester.pumpWidget(const StartupApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(
      const StartupApp(error: 'Перевірте налаштування Firebase.'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Перевірте налаштування Firebase.'), findsOneWidget);
  });
  for (final route in [
    '/',
    '/login',
    '/register',
    '/reset-password',
    '/missing',
  ]) {
    testWidgets('$route fits 320px with 200% text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, route);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Populated calendar fits 320px at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, '/', populated: true);
    expect(tester.takeException(), isNull);
  });
}
