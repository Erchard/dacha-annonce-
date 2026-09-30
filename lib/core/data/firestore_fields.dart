import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/domain_exception.dart';

class Fields {
  Fields(this.data, Set<String> keys) {
    if (data.length != keys.length || !data.keys.toSet().containsAll(keys)) {
      throw const DomainException(
        ErrorCode.validation,
        technicalCode: 'invalid-schema',
      );
    }
    if (value<int>('schemaVersion') != 1) {
      throw const DomainException(ErrorCode.validation, field: 'schemaVersion');
    }
  }
  final Map<String, dynamic> data;
  T value<T>(String key) {
    final v = data[key];
    if (v is! T) {
      throw DomainException(
        ErrorCode.validation,
        field: key,
        technicalCode: 'invalid-type',
      );
    }
    return v;
  }

  DateTime time(String key) {
    final timestamp = value<Timestamp>(key);
    if (timestamp.nanoseconds % 1000 != 0) {
      throw DomainException(
        ErrorCode.validation,
        field: key,
        technicalCode: 'unsupported-time-precision',
      );
    }
    return timestamp.toDate().toUtc();
  }

  T enumeration<T extends Enum>(String key, List<T> values) {
    final raw = value<String>(key);
    for (final v in values) {
      if (v.name == raw) return v;
    }
    throw DomainException(
      ErrorCode.validation,
      field: key,
      technicalCode: 'unknown-enum',
    );
  }
}

DomainException firebaseFailure(FirebaseException error) =>
    DomainException(switch (error.code) {
      'unauthenticated' => ErrorCode.unauthenticated,
      'permission-denied' => ErrorCode.permissionDenied,
      'not-found' => ErrorCode.notFound,
      'unavailable' || 'deadline-exceeded' => ErrorCode.networkUnavailable,
      'resource-exhausted' => ErrorCode.quotaExceeded,
      'aborted' => ErrorCode.staleVersion,
      _ => ErrorCode.unexpected,
    }, technicalCode: error.code);

Future<T> firestoreCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FirebaseException catch (error) {
    throw firebaseFailure(error);
  }
}

/// Preserve a domain rejection across FlutterFire Web's Dart/JS promise boundary.
/// The callback still throws, so Firestore aborts the transaction normally.
Future<void> firestoreTransaction(
  FirebaseFirestore db,
  Future<void> Function(Transaction transaction) action,
) async {
  DomainException? rejection;
  StackTrace? rejectionStack;
  try {
    await db.runTransaction((transaction) async {
      rejection = null;
      rejectionStack = null;
      try {
        await action(transaction);
      } on DomainException catch (error, stack) {
        rejection = error;
        rejectionStack = stack;
        rethrow;
      }
    });
  } catch (_) {
    if (rejection != null) {
      Error.throwWithStackTrace(rejection!, rejectionStack!);
    }
    rethrow;
  }
}
