import '../../../core/domain/page.dart';
import 'user_profile.dart';

abstract interface class AuthRepository {
  Stream<AuthSession?> get session;
  Future<void> register(String email, String password, String displayName);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendVerification();
  Future<void> resetPassword(String email);
  Future<void> reloadUser();
}

abstract interface class UserRepository {
  Stream<UserProfile?> watchMyProfile();
  Future<void> updateMyDisplayName(String displayName);
  Future<Page<UserProfile>> listProfiles(
    PageRequest page, {
    required UserRole role,
  });
  Future<void> setDisabled(
    String uid,
    bool disabled, {
    required int expectedRevision,
  });
}
