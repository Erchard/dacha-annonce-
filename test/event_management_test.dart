import 'package:dacha_annonce/app/data/app_repository.dart';
import 'package:dacha_annonce/app/presentation/calendar_pages.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/time/booking_time.dart';
import 'package:dacha_annonce/core/time/time_zone_service.dart';
import 'package:dacha_annonce/features/auth/domain/user_profile.dart';
import 'package:dacha_annonce/features/calendar/domain/public_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

class EventRepository implements AppRepository {
  @override
  Future<PublicEvent?> getPublishedEvent(String id) async => PublicEvent(
    id: id,
    title: 'Минула подія',
    description: 'Тест',
    roomId: 'room',
    roomNameSnapshot: 'Локація',
    locationSnapshot: '',
    responsibleName: '',
    interval: BookingInterval(
      DateTime.utc(2020, 1, 1, 10),
      DateTime.utc(2020, 1, 1, 11),
    ),
    bookingVersion: 1,
    publishedAt: DateTime.utc(2020),
    updatedAt: DateTime.utc(2020),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

void main() {
  setUpAll(() async {
    TimeZoneService();
    await initializeDateFormatting('uk');
  });
  for (final admin in [true, false]) {
    testWidgets('past calendar event management: admin=$admin', (tester) async {
      final router = GoRouter(
        initialLocation: '/events/past',
        routes: [
          GoRoute(
            path: '/events/:id',
            builder: (_, state) => EventPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/bookings/:id',
            builder: (_, state) => Text('manage:${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      final profile = admin
          ? UserProfile(
              id: 'admin',
              displayName: 'MI',
              role: UserRole.admin,
              isDisabled: false,
              createdAt: DateTime.utc(2020),
              updatedAt: DateTime.utc(2020),
              createdBy: 'admin',
              updatedBy: 'admin',
              adminRevision: 0,
              lastAdminAuditId: null,
            )
          : null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(EventRepository()),
            sessionProvider.overrideWith((ref) => Stream.value(null)),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final control = find.text('Керувати подією / Видалити');
      expect(control, admin ? findsOneWidget : findsNothing);
      if (admin) {
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(find.text('manage:past'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
