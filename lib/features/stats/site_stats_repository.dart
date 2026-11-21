import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/data/firestore_fields.dart';
import '../../core/errors/domain_exception.dart';
import '../../core/web/site_stats_storage.dart';

class SiteStatsSummary {
  SiteStatsSummary({required this.pageViews, required this.visitors});
  final int pageViews;
  final int visitors;
}

class SiteStatsRepository {
  SiteStatsRepository(this.db);
  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> get _summary =>
      db.collection('siteStats').doc('summary');

  /// Admin read. Returns null when the document does not exist yet.
  Future<SiteStatsSummary?> readSummary() => firestoreCall(() async {
    final snap = await _summary.get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final views = data['pageViews'];
    final visitors = data['visitors'];
    if (views is! int || visitors is! int || views < 0 || visitors < 0) {
      throw const DomainException(ErrorCode.validation, field: 'siteStats');
    }
    return SiteStatsSummary(pageViews: views, visitors: visitors);
  });

  /// Record one navigation. Idempotent per path/session and per browser visitor.
  Future<void> recordNavigation(String path) async {
    final countView = !wasPathViewedThisSession(path);
    final countVisitor = !wasVisitorCounted();
    if (!countView && !countVisitor) return;

    await firestoreCall(() async {
      final patch = <String, Object>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (countView) patch['pageViews'] = FieldValue.increment(1);
      if (countVisitor) patch['visitors'] = FieldValue.increment(1);
      try {
        await _summary.update(patch);
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
        try {
          await _summary.set({
            'pageViews': countView ? 1 : 0,
            'visitors': countVisitor ? 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (createError) {
          // Parallel first visits: retry increment once the doc exists.
          if (createError.code != 'already-exists') rethrow;
          await _summary.update(patch);
        }
      }
    });

    if (countView) markPathViewedThisSession(path);
    if (countVisitor) markVisitorCounted();
  }
}
