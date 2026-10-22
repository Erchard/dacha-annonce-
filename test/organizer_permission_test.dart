import 'package:dacha_annonce/app/app.dart';
import 'package:dacha_annonce/app/data/app_repository.dart';
import 'package:dacha_annonce/app/presentation/admin_pages.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/domain/page.dart' as paging;
import 'package:dacha_annonce/features/auth/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class OrganizerRepository implements AppRepository {
  bool allowed = false;
  int revision = 0;
  @override
  Future<paging.Page<UserProfile>> listProfiles(
    paging.PageRequest page, {
    required UserRole role,
  }) async => paging.Page([
    UserProfile(
      id: 'organizer-id',
      displayName: 'Організатор',
      role: UserRole.organizer,
      isDisabled: false,
      canPublish: allowed,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      createdBy: 'organizer-id',
      updatedBy: 'admin',
      adminRevision: revision,
      lastAdminAuditId: revision == 0 ? null : 'audit-$revision',
    ),
  ], null);
  @override
  Future<void> setPublishing(
    String id,
    bool value, {
    required int expectedRevision,
  }) async {
    expect(id, 'organizer-id');
    expect(expectedRevision, revision);
    allowed = value;
    revision++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

void main() {
  testWidgets(
    'MI confirms grant and revoke; mobile control refreshes permission',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = OrganizerRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            sessionProvider.overrideWith((ref) => Stream.value(null)),
            profileProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(theme: dachaTheme(), home: const AdminUsersPage()),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Дозволити самостійну публікацію',
        'Забрати самостійну публікацію',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Підтвердити'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(repo.allowed, isFalse);
      expect(repo.revision, 2);
    },
  );
}
