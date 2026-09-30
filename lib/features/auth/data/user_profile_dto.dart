import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../domain/user_profile.dart';

class UserProfileDto {
  static const keys = {
    'displayName',
    'role',
    'isDisabled',
    'createdAt',
    'updatedAt',
    'createdBy',
    'updatedBy',
    'schemaVersion',
    'adminRevision',
    'lastAdminAuditId',
  };
  static UserProfile decode(String id, Map<String, dynamic> data) {
    final f = Fields(data, keys);
    return UserProfile(
      id: id,
      displayName: f.value('displayName'),
      role: f.enumeration('role', UserRole.values),
      isDisabled: f.value('isDisabled'),
      createdAt: f.time('createdAt'),
      updatedAt: f.time('updatedAt'),
      createdBy: f.value('createdBy'),
      updatedBy: f.value('updatedBy'),
      adminRevision: f.value('adminRevision'),
      lastAdminAuditId: f.value<String?>('lastAdminAuditId'),
    );
  }

  static Map<String, dynamic> encode(UserProfile user) => {
    'displayName': user.displayName,
    'role': user.role.name,
    'isDisabled': user.isDisabled,
    'createdAt': Timestamp.fromDate(user.createdAt),
    'updatedAt': Timestamp.fromDate(user.updatedAt),
    'createdBy': user.createdBy,
    'updatedBy': user.updatedBy,
    'schemaVersion': 1,
    'adminRevision': user.adminRevision,
    'lastAdminAuditId': user.lastAdminAuditId,
  };
}
