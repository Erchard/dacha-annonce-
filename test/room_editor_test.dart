import 'package:dacha_annonce/app/app.dart';
import 'package:dacha_annonce/app/data/app_repository.dart';
import 'package:dacha_annonce/app/presentation/admin_pages.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/domain/page.dart' as paging;
import 'package:dacha_annonce/features/rooms/domain/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RoomRepository implements AppRepository {
  Room? saved;
  @override
  String newRoomId() => 'new-room';
  @override
  Future<paging.Page<Room>> listRooms(
    paging.PageRequest page, {
    bool activeOnly = true,
  }) async => paging.Page(saved == null ? [] : [saved!], null);
  @override
  Future<void> upsert(Room room, {required int expectedRevision}) async {
    saved = room;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

void main() {
  Future<RoomRepository> open(WidgetTester tester) async {
    final repo = RoomRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(theme: dachaTheme(), home: const AdminRoomsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Додати локацію'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Вітальня');
    return repo;
  }

  for (final entry in <String, int?>{'20': 20, '': null, '   ': null}.entries) {
    testWidgets('Room capacity ${entry.key} saves and reopens', (tester) async {
      final repo = await open(tester);
      await tester.enterText(find.byType(TextFormField).at(3), entry.key);
      await tester.tap(find.text('Зберегти'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNotNull);
      expect(repo.saved!.capacity, entry.value);
      await tester.tap(find.text('Редагувати'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(3))
            .controller!
            .text,
        entry.value?.toString() ?? '',
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Invalid range is explained and correcting it permits saving', (
    tester,
  ) async {
    final repo = await open(tester);
    await tester.enterText(find.byType(TextFormField).at(3), '15-20');
    await tester.tap(find.text('Зберегти'));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    await tester.enterText(find.byType(TextFormField).at(3), '20');
    await tester.tap(find.text('Зберегти'));
    await tester.pumpAndSettle();
    expect(repo.saved!.capacity, 20);
  });
  testWidgets('Room form fits 320px at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    expect(tester.takeException(), isNull);
  });
}
