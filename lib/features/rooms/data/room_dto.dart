import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../domain/room.dart';

class RoomDto {
  static const keys = {
    'name',
    'description',
    'locationLabel',
    'capacity',
    'isActive',
    'sortOrder',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'revision',
    'lastAuditId',
  };
  static Room decode(String id, Map<String, dynamic> data) {
    final f = Fields(data, keys);
    return Room(
      id: id,
      name: f.value('name'),
      description: f.value('description'),
      locationLabel: f.value('locationLabel'),
      capacity: f.value<int?>('capacity'),
      isActive: f.value('isActive'),
      sortOrder: f.value('sortOrder'),
      createdAt: f.time('createdAt'),
      updatedAt: f.time('updatedAt'),
      revision: f.value('revision'),
      lastAuditId: f.value('lastAuditId'),
    );
  }

  static Map<String, dynamic> encode(Room room) => {
    'name': room.name,
    'description': room.description,
    'locationLabel': room.locationLabel,
    'capacity': room.capacity,
    'isActive': room.isActive,
    'sortOrder': room.sortOrder,
    'createdAt': Timestamp.fromDate(room.createdAt),
    'updatedAt': Timestamp.fromDate(room.updatedAt),
    'schemaVersion': 1,
    'revision': room.revision,
    'lastAuditId': room.lastAuditId,
  };
}
