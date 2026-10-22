import 'package:dacha_annonce/app/app.dart';
import 'package:dacha_annonce/app/presentation/admin_pages.dart';
import 'package:dacha_annonce/app/providers.dart';
import 'package:dacha_annonce/core/errors/domain_exception.dart';
import 'package:dacha_annonce/features/rooms/domain/room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'room_editor_test.dart' show RoomRepository;

class DeleteRoomRepository extends RoomRepository {
  bool blocked = true;
  @override
  Future<void> deleteRoom(Room room) async {
    if (blocked) {
      throw const DomainException(
        ErrorCode.validation,
        field: 'roomHasBookings',
      );
    }
    saved = null;
  }
}

void main() {
  testWidgets('blocked room deletion remains explained and can be retried', (
    tester,
  ) async {
    final repo = DeleteRoomRepository()
      ..saved = Room(
        id: 'room',
        name: 'Архівна локація',
        description: '',
        locationLabel: '',
        capacity: null,
        isActive: false,
        sortOrder: 0,
        createdAt: DateTime.utc(2020),
        updatedAt: DateTime.utc(2020),
        revision: 1,
        lastAuditId: 'audit',
      );
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
    Future<void> remove() async {
      await tester.ensureVisible(find.text('Видалити'));
      await tester.tap(find.text('Видалити'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Підтвердити'));
      await tester.pumpAndSettle();
    }

    await remove();
    await tester.pump(const Duration(seconds: 10));
    expect(
      find.textContaining('У локації залишились сьогоднішні або майбутні'),
      findsOneWidget,
    );
    expect(repo.saved, isNotNull);
    repo.blocked = false;
    await remove();
    expect(
      find.textContaining('У локації залишились сьогоднішні або майбутні'),
      findsNothing,
    );
    expect(repo.saved, isNull);
    expect(tester.takeException(), isNull);
  });
}

