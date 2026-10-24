import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/calendar/event_calendar_export.dart';
import '../../core/web/share_actions.dart';
import '../../core/widgets/direction_chip.dart';
import '../../features/calendar/domain/public_event.dart';
import 'shared.dart';

Future<void> showEventPreview(BuildContext context, PublicEvent event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '${localDate(event.interval.start)} · '
            '${localTime(event.interval.start)}–${localTime(event.interval.end)} (Київ)',
          ),
          Text('${event.roomNameSnapshot} · ${event.locationSnapshot}'),
          if (event.responsibleName.isNotEmpty)
            Text('Відповідальний: ${event.responsibleName}'),
          if (event.directions.isNotEmpty) ...[
            const SizedBox(height: 10),
            DirectionChipWrap(directions: event.directions),
          ],
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              event.description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/events/${Uri.encodeComponent(event.id)}');
                },
                child: const Text('Відкрити сторінку'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  downloadTextFile(
                    fileName: eventIcsFileName(event),
                    content: eventIcsContent(event),
                    mimeType: 'text/calendar;charset=utf-8',
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('.ics'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    openExternalUrl(googleCalendarUrl(event).toString()),
                icon: const Icon(Icons.event_available),
                label: const Text('Google'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
