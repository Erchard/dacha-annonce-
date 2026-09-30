import '../../../core/errors/domain_exception.dart';

enum UserRole { organizer, admin, developer }

class UserProfile {
  UserProfile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.isDisabled,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.adminRevision,
    required this.lastAdminAuditId,
  }) {
    checkedText(displayName, 'displayName', 2, 80);
    if (adminRevision < 0 ||
        (adminRevision == 0) != (lastAdminAuditId == null)) {
      throw const DomainException(ErrorCode.validation, field: 'adminRevision');
    }
  }
  final String id, displayName, createdBy, updatedBy;
  final UserRole role;
  final bool isDisabled;
  final DateTime createdAt, updatedAt;
  final int adminRevision;
  final String? lastAdminAuditId;
}

class AuthSession {
  const AuthSession(this.uid, {required this.emailVerified});
  final String uid;
  final bool emailVerified;
}
