import 'dart:convert';

String? _memory;

void saveSupportDraft({
  required String type,
  required String title,
  required String body,
}) {
  _memory = jsonEncode({
    'type': type,
    'title': title,
    'body': body,
    'at': DateTime.now().toUtc().toIso8601String(),
  });
}

({String type, String title, String body})? loadSupportDraft() {
  return decodeSupportDraft(_memory);
}

void clearSupportDraft() => _memory = null;

({String type, String title, String body})? decodeSupportDraft(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.tryParse(map['at'] as String? ?? '');
    if (at == null ||
        DateTime.now().toUtc().difference(at.toUtc()) >
            const Duration(days: 14)) {
      return null;
    }
    final type = map['type'] as String? ?? 'bug';
    if (!['bug', 'feature', 'feedback'].contains(type)) return null;
    return (
      type: type,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}
