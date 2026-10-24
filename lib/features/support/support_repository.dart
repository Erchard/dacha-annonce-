import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/data/firestore_fields.dart';
import '../../core/domain/page.dart';
import '../../core/errors/domain_exception.dart';

const ticketStatuses = [
  'new',
  'accepted',
  'in_progress',
  'done',
  'rejected',
  'closed',
];
const ticketPriorities = ['low', 'normal', 'high'];
const ticketTypes = ['bug', 'feature', 'feedback'];
const attachmentContentTypes = {'image/jpeg', 'image/png', 'image/webp'};
const maxAttachmentBytes = 700000;
const maxAttachmentsPerTicket = 5;

List<String> allowedTicketStatuses(String role, String status) =>
    role == 'developer'
    ? switch (status) {
        'new' => ['accepted', 'rejected'],
        'accepted' => ['in_progress', 'rejected'],
        'in_progress' => ['done'],
        'done' || 'rejected' => ['closed', 'accepted'],
        'closed' => ['accepted'],
        _ => [],
      }
    : role == 'admin'
    ? switch (status) {
        'new' => ['closed'],
        'done' => ['closed', 'accepted'],
        'rejected' => ['closed', 'accepted'],
        'closed' => ['accepted'],
        _ => [],
      }
    : [];

class Ticket {
  static const _keys = {
    'type',
    'title',
    'body',
    'status',
    'priority',
    'createdBy',
    'createdAt',
    'updatedBy',
    'updatedAt',
    'lastActivityAt',
    'version',
    'lastAction',
    'schemaVersion',
    'lastHistoryId',
    'lastCommentId',
  };

  Ticket(this.id, Map<String, dynamic> data) {
    // Ignore unknown keys so older/newer documents still open in the UI.
    final f = Fields({
      for (final key in _keys) key: data[key],
    }, _keys);
    type = f.value<String>('type');
    title = checkedText(f.value<String>('title'), 'title', 3, 160);
    body = checkedText(f.value<String>('body'), 'body', 10, 10000);
    status = f.value<String>('status');
    priority = f.value<String>('priority');
    version = f.value<int>('version');
    createdAt = f.time('createdAt');
    lastActivityAt = f.time('lastActivityAt');
    if (!ticketTypes.contains(type) ||
        !ticketStatuses.contains(status) ||
        !ticketPriorities.contains(priority) ||
        version < 1) {
      throw const DomainException(ErrorCode.validation, field: 'ticket');
    }
  }
  final String id;
  late final String type, title, body, status, priority;
  late final int version;
  late final DateTime createdAt, lastActivityAt;
}

class SupportEntry {
  SupportEntry(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class SupportRepository {
  SupportRepository(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  String newId() => db.collection('supportTickets').doc().id;
  Future<Ticket?> get(String id) => firestoreCall(() async {
    final d = await db.collection('supportTickets').doc(id).get();
    return d.exists ? Ticket(id, d.data()!) : null;
  });
  Future<Page<Ticket>> list(PageRequest page, {String? status}) =>
      firestoreCall(() async {
        Query<Map<String, dynamic>> q = db.collection('supportTickets');
        if (status != null) q = q.where('status', isEqualTo: status);
        final key = 'support:$status';
        q = q
            .orderBy('lastActivityAt', descending: true)
            .orderBy(FieldPath.documentId);
        if (page.after case final c?) {
          if (c.queryKey != key) {
            throw const DomainException(ErrorCode.validation, field: 'cursor');
          }
          q = q.startAfter([c.value, c.id]);
        }
        final docs = (await q.limit(page.limit).get()).docs;
        return Page(
          docs.map((d) => Ticket(d.id, d.data())),
          docs.length == page.limit
              ? PageCursor(
                  queryKey: key,
                  value: docs.last.data()['lastActivityAt'],
                  id: docs.last.id,
                )
              : null,
        );
      });
  Future<Page<SupportEntry>> entries(
    String id,
    String collection,
    PageRequest page,
  ) => firestoreCall(() async {
    if (!['comments', 'history', 'attachments'].contains(collection)) {
      throw const DomainException(ErrorCode.validation);
    }
    final order = collection == 'history' ? 'version' : 'createdAt',
        key = 'support:$id:$collection';
    Query<Map<String, dynamic>> q = db
        .collection('supportTickets')
        .doc(id)
        .collection(collection)
        .orderBy(order)
        .orderBy(FieldPath.documentId);
    if (page.after case final c?) {
      if (c.queryKey != key) {
        throw const DomainException(ErrorCode.validation, field: 'cursor');
      }
      q = q.startAfter([c.value, c.id]);
    }
    final docs = (await q.limit(page.limit).get()).docs;
    return Page(
      docs.map((d) => SupportEntry(d.id, d.data())),
      docs.length == page.limit
          ? PageCursor(
              queryKey: key,
              value: docs.last.data()[order],
              id: docs.last.id,
            )
          : null,
    );
  });
  Future<void> create(
    String id, {
    required String type,
    required String title,
    required String body,
  }) => _write(
    id,
    0,
    'created',
    type: type,
    title: checkedText(title.trim(), 'title', 3, 160),
    body: checkedText(body.trim(), 'body', 10, 10000),
  );
  Future<void> comment(Ticket t, String body) => _write(
    t.id,
    t.version,
    'commented',
    comment: checkedText(body.trim(), 'comment', 1, 5000),
  );
  Future<void> status(Ticket t, String status, {String? comment}) => _write(
    t.id,
    t.version,
    'status_changed',
    status: status,
    comment: comment,
  );
  Future<void> priority(Ticket t, String priority) =>
      _write(t.id, t.version, 'priority_changed', priority: priority);
  Future<void> editContent(Ticket t, {required String title, required String body}) =>
      _write(
        t.id,
        t.version,
        'edited',
        title: checkedText(title.trim(), 'title', 3, 160),
        body: checkedText(body.trim(), 'body', 10, 10000),
      );

  Future<void> addAttachment(
    String ticketId, {
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) => firestoreCall(() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw const DomainException(ErrorCode.unauthenticated);
    final name = checkedText(fileName.trim(), 'fileName', 1, 160);
    if (!attachmentContentTypes.contains(contentType) ||
        bytes.isEmpty ||
        bytes.length > maxAttachmentBytes) {
      throw const DomainException(ErrorCode.validation, field: 'attachment');
    }
    final ticket = db.collection('supportTickets').doc(ticketId);
    final profile = (await db.collection('users').doc(uid).get()).data();
    if (profile == null ||
        profile['isDisabled'] == true ||
        !['admin', 'developer'].contains(profile['role'])) {
      throw const DomainException(ErrorCode.permissionDenied);
    }
    final existing = await ticket
        .collection('attachments')
        .limit(maxAttachmentsPerTicket)
        .get();
    if (existing.size >= maxAttachmentsPerTicket) {
      throw const DomainException(
        ErrorCode.validation,
        field: 'attachmentLimit',
      );
    }
    if (!(await ticket.get()).exists) {
      throw const DomainException(ErrorCode.notFound);
    }
    await ticket.collection('attachments').doc().set({
      'fileName': name,
      'contentType': contentType,
      'bytes': Blob(bytes),
      'size': bytes.length,
      'authorId': uid,
      'authorRole': profile['role'],
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
  });

  Future<void> _write(
    String id,
    int version,
    String action, {
    String? type,
    String? title,
    String? body,
    String? status,
    String? priority,
    String? comment,
  }) => firestoreCall(() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw const DomainException(ErrorCode.unauthenticated);
    if (comment != null) {
      comment = checkedText(comment!.trim(), 'comment', 1, 5000);
    }
    final ticket = db.collection('supportTickets').doc(id),
        commentRef = ticket.collection('comments').doc();
    await firestoreTransaction(db, (tx) async {
      final old = (await tx.get(ticket)).data();
      final profile = (await tx.get(db.collection('users').doc(uid))).data();
      if (profile == null || profile['isDisabled'] == true) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      final role = profile['role'] as String;
      final staff = role == 'admin' || role == 'developer';
      final canCreateFeedback =
          role == 'organizer' || role == 'admin';
      if (!staff && !(old == null && action == 'created' && canCreateFeedback)) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      if ((old?['version'] ?? 0) != version) {
        throw const DomainException(ErrorCode.staleVersion);
      }
      if (old == null &&
          (action != 'created' ||
              !ticketTypes.contains(type) ||
              (role == 'organizer' && type != 'feedback') ||
              (role != 'admin' && role != 'organizer'))) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      if (action == 'status_changed' &&
          (!allowedTicketStatuses(role, old!['status']).contains(status) ||
              status == 'accepted' &&
                  ['done', 'rejected', 'closed'].contains(old['status']) &&
                  comment == null)) {
        throw const DomainException(ErrorCode.validation, field: 'status');
      }
      if (action == 'priority_changed' &&
          (role != 'developer' ||
              !ticketPriorities.contains(priority) ||
              priority == old!['priority'])) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      if (action == 'edited' &&
          (role != 'admin' ||
              old == null ||
              old['status'] != 'new' ||
              title == null ||
              body == null ||
              (title == old['title'] && body == old['body']))) {
        throw const DomainException(ErrorCode.permissionDenied);
      }
      final now = FieldValue.serverTimestamp();
      final next = <String, dynamic>{
        ...?old,
        if (old == null) ...{
          'type': type,
          'title': title,
          'body': body,
          'status': 'new',
          'priority': 'normal',
          'createdBy': uid,
          'createdAt': now,
          'schemaVersion': 1,
          'lastCommentId': null,
        },
        if (action == 'edited') ...{
          'title': title,
          'body': body,
        },
        'status': ?status,
        'priority': ?priority,
        'updatedBy': uid,
        'updatedAt': now,
        'lastActivityAt': now,
        'version': version + 1,
        'lastAction': action,
        'lastHistoryId': '${version + 1}',
        if (comment != null) 'lastCommentId': commentRef.id,
      };
      tx.set(ticket, next);
      tx.set(ticket.collection('history').doc('${version + 1}'), {
        'version': version + 1,
        'action': action,
        'actorId': uid,
        'actorRole': role,
        'at': now,
        'fromStatus': old?['status'],
        'toStatus': next['status'] ?? old?['status'],
        'commentId': comment == null ? null : commentRef.id,
        'fromPriority': old?['priority'],
        'toPriority': next['priority'] ?? old?['priority'],
      });
      if (comment != null) {
        tx.set(commentRef, {
          'body': comment,
          'authorId': uid,
          'authorRole': role,
          'createdAt': now,
          'ticketVersion': version + 1,
          'schemaVersion': 1,
        });
      }
    });
  });
}
