import '../../../core/domain/page.dart';
import 'room.dart';

abstract interface class RoomRepository {
  Stream<Page<Room>> watchActiveRooms(PageRequest page);
  Future<Room?> getRoom(String id);
  Future<void> upsert(Room room, {required int expectedRevision});
  Future<void> archive(String id, {required int expectedRevision});
}
