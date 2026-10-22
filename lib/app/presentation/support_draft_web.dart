import 'dart:convert';
import 'dart:html' as html;

import 'support_draft_stub.dart' show decodeSupportDraft;

const _key = 'dacha.supportTicketDraft.v1';

void saveSupportDraft({
  required String type,
  required String title,
  required String body,
}) {
  if (title.trim().isEmpty && body.trim().isEmpty) {
    clearSupportDraft();
    return;
  }
  html.window.localStorage[_key] = jsonEncode({
    'type': type,
    'title': title,
    'body': body,
    'at': DateTime.now().toUtc().toIso8601String(),
  });
}

({String type, String title, String body})? loadSupportDraft() =>
    decodeSupportDraft(html.window.localStorage[_key]);

void clearSupportDraft() => html.window.localStorage.remove(_key);
