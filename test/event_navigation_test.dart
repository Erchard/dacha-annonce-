import 'package:dacha_annonce/app/presentation/shared.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/features/auth/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final role in [UserRole.organizer, UserRole.admin]) {
    testWidgets('visible event management at 320px for ${role.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = UserProfile(
        id: 'user',
        displayName: 'Користувач',
        role: role,
        isDisabled: false,
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        createdBy: 'user',
        updatedBy: 'user',
        adminRevision: 0,
        lastAdminAuditId: null,
      );
      final target = role == UserRole.admin ? '/admin' : '/my-bookings';
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const AppFrame(title: 'Календар', child: SizedBox()),
          ),
          GoRoute(path: target, builder: (_, _) => const Text('Список подій')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => Stream.value(null)),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Особисте меню'));
      await tester.pumpAndSettle();
      final control = find.text(
        role == UserRole.admin ? 'Керувати подіями' : 'Мої події та заявки',
      );
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(find.text('Список подій'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
