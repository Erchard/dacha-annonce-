import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/page.dart';
import '../../features/support/support_repository.dart';
import '../../features/auth/domain/user_profile.dart';
import '../providers.dart';
import 'shared.dart';

String ticketStatusLabel(String value) => switch (value) {
  'new' => 'Нове',
  'accepted' => 'Прийнято',
  'in_progress' => 'У роботі',
  'done' => 'Виконано',
  'rejected' => 'Відхилено',
  'closed' => 'Закрито',
  _ => value,
};
String priorityLabel(String value) => switch (value) {
  'low' => 'Низький',
  'normal' => 'Звичайний',
  'high' => 'Високий',
  _ => value,
};
String typeLabel(String value) => switch (value) {
  'bug' => 'Помилка',
  'feature' => 'Пропозиція',
  'feedback' => 'Відгук',
  _ => value,
};

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  List<Ticket> tickets = [];
  PageCursor? next;
  String? status;
  Object? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(true));
  }

  Future<void> load(bool reset) async {
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        tickets = [];
        next = null;
      }
    });
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .list(PageRequest(after: next), status: status);
      if (mounted) {
        setState(() {
          tickets = [...tickets, ...page.items];
          next = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Написати розробнику',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Звернення бачать адміністрація та розробник. Автоматичні email-сповіщення ще не підключені.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (ref.watch(profileProvider).asData?.value?.role ==
                UserRole.admin)
              FilledButton(
                onPressed: () => context.go('/support/new'),
                child: const Text('Нове звернення'),
              ),
            DropdownButton<String>(
              value: status,
              hint: const Text('Усі статуси'),
              onChanged: busy
                  ? null
                  : (v) {
                      status = v;
                      load(true);
                    },
              items: [
                const DropdownMenuItem(value: null, child: Text('Усі статуси')),
                for (final s in ticketStatuses)
                  DropdownMenuItem(value: s, child: Text(ticketStatusLabel(s))),
              ],
            ),
            TextButton(
              onPressed: busy ? null : () => load(true),
              child: const Text('Оновити'),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Problem(error!, retry: () => load(true)),
        if (!busy && error == null && tickets.isEmpty)
          const Text('Звернень поки немає.'),
        for (final t in tickets)
          Card(
            child: ListTile(
              title: Text(t.title),
              subtitle: Text(
                '${ticketStatusLabel(t.status)} · ${priorityLabel(t.priority)} · ${localDate(t.lastActivityAt)}',
              ),
              onTap: () => context.go('/support/${t.id}'),
            ),
          ),
        if (next != null)
          TextButton(
            onPressed: busy ? null : () => load(false),
            child: const Text('Завантажити ще'),
          ),
      ],
    ),
  );
}

class NewTicketPage extends ConsumerStatefulWidget {
  const NewTicketPage({super.key});
  @override
  ConsumerState<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends ConsumerState<NewTicketPage> {
  final title = TextEditingController(), body = TextEditingController();
  final form = GlobalKey<FormState>();
  String type = 'bug';
  late final String id;
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    id = ref.read(supportRepositoryProvider).newId();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(supportRepositoryProvider)
          .create(id, type: type, title: title.text, body: body.text);
      if (mounted) context.go('/support/$id');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Нове звернення',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Тип'),
            items: [
              for (final t in ticketTypes)
                DropdownMenuItem(value: t, child: Text(typeLabel(t))),
            ],
            onChanged: busy ? null : (v) => type = v!,
          ),
          TextFormField(
            controller: title,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Тема'),
            validator: (v) => (v?.trim().runes.length ?? 0) < 3
                ? 'Щонайменше 3 символи'
                : null,
          ),
          TextFormField(
            controller: body,
            maxLength: 10000,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'Опис'),
            validator: (v) => (v?.trim().runes.length ?? 0) < 10
                ? 'Щонайменше 10 символів'
                : null,
          ),
          if (error != null) Problem(error!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Збереження…' : 'Створити звернення'),
          ),
        ],
      ),
    ),
  );
}

class TicketPage extends ConsumerStatefulWidget {
  const TicketPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends ConsumerState<TicketPage> {
  Ticket? ticket;
  List<SupportEntry> comments = [], history = [];
  PageCursor? commentNext, historyNext;
  Object? error;
  bool busy = true;
  final comment = TextEditingController();
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider),
          t = await ref.read(supportRepositoryProvider).get(widget.id);
      final c = t == null
          ? null
          : await repo.entries(widget.id, 'comments', PageRequest());
      final h = t == null
          ? null
          : await repo.entries(widget.id, 'history', PageRequest());
      if (mounted) {
        setState(() {
          ticket = t;
          comments = c?.items ?? [];
          history = h?.items ?? [];
          commentNext = c?.next;
          historyNext = h?.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(
    Future<void> Function(SupportRepository, Ticket) action,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action(ref.read(supportRepositoryProvider), ticket!);
      comment.clear();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> more(String collection) async {
    setState(() => busy = true);
    try {
      final p = await ref
          .read(supportRepositoryProvider)
          .entries(
            widget.id,
            collection,
            PageRequest(
              after: collection == 'comments' ? commentNext : historyNext,
            ),
          );
      if (mounted) {
        setState(() {
          if (collection == 'comments') {
            comments = [...comments, ...p.items];
            commentNext = p.next;
          } else {
            history = [...history, ...p.items];
            historyNext = p.next;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ticket,
        role = ref.watch(profileProvider).asData?.value?.role.name ?? '';
    return AppFrame(
      title: t?.title ?? 'Звернення',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) Problem(error!, retry: load),
          if (t == null && !busy && error == null)
            const Text('Звернення не знайдено.'),
          if (t != null) ...[
            Text(
              '${typeLabel(t.type)} · ${ticketStatusLabel(t.status)} · ${priorityLabel(t.priority)}',
            ),
            const SizedBox(height: 12),
            SelectableText(t.body),
            const Divider(height: 32),
            TextField(
              controller: comment,
              minLines: 2,
              maxLines: 8,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Коментар',
                helperText:
                    'Для повторного відкриття обов’язково поясніть причину.',
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => act((r, t) => r.comment(t, comment.text)),
                  child: const Text('Додати коментар'),
                ),
                for (final status in allowedTicketStatuses(role, t.status))
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (await confirmAction(
                              context,
                              'Змінити статус?',
                              ticketStatusLabel(status),
                            )) {
                              await act(
                                (r, t) => r.status(
                                  t,
                                  status,
                                  comment: comment.text.trim().isEmpty
                                      ? null
                                      : comment.text,
                                ),
                              );
                            }
                          },
                    child: Text(ticketStatusLabel(status)),
                  ),
                if (role == 'developer')
                  DropdownButton<String>(
                    value: t.priority,
                    items: [
                      for (final p in ticketPriorities)
                        DropdownMenuItem(
                          value: p,
                          child: Text(priorityLabel(p)),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null && v != t.priority) {
                              act((r, t) => r.priority(t, v));
                            }
                          },
                  ),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Оновити'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Коментарі', style: Theme.of(context).textTheme.titleLarge),
            if (comments.isEmpty) const Text('Коментарів поки немає.'),
            for (final c in comments)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.data['authorRole'] == 'admin' ? 'Адміністрація' : 'Розробник'} · ${localDate((c.data['createdAt'] as Timestamp).toDate())} ${localTime((c.data['createdAt'] as Timestamp).toDate())}',
                      ),
                      const SizedBox(height: 8),
                      SelectableText(c.data['body'] as String),
                    ],
                  ),
                ),
              ),
            if (commentNext != null)
              TextButton(
                onPressed: busy ? null : () => more('comments'),
                child: const Text('Ще коментарі'),
              ),
            const SizedBox(height: 20),
            ExpansionTile(
              title: const Text('Історія змін'),
              children: [
                for (final h in history)
                  ListTile(
                    title: Text(
                      '#${h.data['version']} · ${h.data['actorRole'] == 'admin' ? 'Адміністрація' : 'Розробник'}',
                    ),
                    subtitle: Text(
                      '${ticketStatusLabel(h.data['toStatus'] as String)} · ${priorityLabel(h.data['toPriority'] as String)} · ${h.data['action']}',
                    ),
                  ),
                if (historyNext != null)
                  TextButton(
                    onPressed: busy ? null : () => more('history'),
                    child: const Text('Ще історія'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
