import '../../features/calendar/domain/public_event.dart';

String _icsEscape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '');

String _icsUtc(DateTime instant) {
  final u = instant.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}T'
      '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

String eventIcsContent(PublicEvent event) {
  final start = _icsUtc(event.interval.start);
  final end = _icsUtc(event.interval.end);
  final stamp = _icsUtc(DateTime.now().toUtc());
  final location = [
    event.roomNameSnapshot,
    event.locationSnapshot,
  ].where((s) => s.trim().isNotEmpty).join(', ');
  final description = [
    event.description,
    if (event.responsibleName.trim().isNotEmpty)
      'Відповідальний: ${event.responsibleName.trim()}',
    if (event.contactPhone.trim().isNotEmpty)
      'Телефон: ${event.contactPhone.trim()}',
    if (event.notes.trim().isNotEmpty) 'Примітки: ${event.notes.trim()}',
  ].where((s) => s.trim().isNotEmpty).join('\n\n');
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Dacha//Event Calendar//UK',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${event.id}@dacha-annonce.web.app',
    'DTSTAMP:$stamp',
    'DTSTART:$start',
    'DTEND:$end',
    'SUMMARY:${_icsEscape(event.title)}',
    'DESCRIPTION:${_icsEscape(description)}',
    if (location.isNotEmpty) 'LOCATION:${_icsEscape(location)}',
    'STATUS:CONFIRMED',
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].join('\r\n');
}

String eventIcsFileName(PublicEvent event) {
  final safe = event.title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .trim();
  final base = safe.isEmpty ? 'event' : safe;
  return '${base.length > 40 ? base.substring(0, 40).trim() : base}.ics';
}

Uri googleCalendarUrl(PublicEvent event) {
  String stamp(DateTime instant) {
    final u = instant.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T'
        '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final details = [
    event.description,
    if (event.responsibleName.trim().isNotEmpty)
      'Відповідальний: ${event.responsibleName.trim()}',
  ].where((s) => s.trim().isNotEmpty).join('\n\n');
  final location = [
    event.roomNameSnapshot,
    event.locationSnapshot,
  ].where((s) => s.trim().isNotEmpty).join(', ');
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': event.title,
    'dates': '${stamp(event.interval.start)}/${stamp(event.interval.end)}',
    'details': details,
    if (location.isNotEmpty) 'location': location,
  });
}
