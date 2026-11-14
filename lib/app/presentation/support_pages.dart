import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/page.dart';
import '../../core/widgets/app_link.dart';
import '../../core/widgets/copy_friendly_image.dart';
import '../../features/support/support_repository.dart';
import '../../features/auth/domain/user_profile.dart';
import '../providers.dart';
import 'shared.dart';
import 'support_draft.dart';

String ticketStatusLabel(String value) => switch (value) {
  'new' => 'Нове',
  'accepted' => 'Очікує роботи',
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
  'general' => 'Загальні питання',
  _ => value,
};

String historySubtitle(Map<String, dynamic> data) {
  final status = data['toStatus'];
  final priority = data['toPriority'];
  final action = data['action'];
  final statusText = status is String && status.isNotEmpty
      ? ticketStatusLabel(status)
      : '—';
  final priorityText = priority is String && priority.isNotEmpty
      ? priorityLabel(priority)
      : '—';
  return '$statusText · $priorityText · ${action ?? ''}';
}

DateTime? supportTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  static const _otherStatuses = [
    'accepted',
    'in_progress',
    'rejected',
    'closed',
  ];

  String? status;
  List<Ticket> filtered = [];
  PageCursor? filteredNext;
  List<Ticket> news = [], dones = [], others = [];
  PageCursor? newsNext, donesNext, othersNext;
  Object? error;
  bool busy = true;

  bool get allSections => status == null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => reload());
  }

  Future<void> reload() async {
    setState(() {
      busy = true;
      error = null;
      filtered = [];
      filteredNext = null;
      news = [];
      dones = [];
      others = [];
      newsNext = donesNext = othersNext = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      if (allSections) {
        final n = await repo.list(PageRequest(), status: 'new');
        final d = await repo.list(PageRequest(), status: 'done');
        final o = await repo.listByStatuses(
          PageRequest(),
          statuses: _otherStatuses,
        );
        if (!mounted) return;
        setState(() {
          news = n.items;
          newsNext = n.next;
          dones = d.items;
          donesNext = d.next;
          others = o.items;
          othersNext = o.next;
        });
      } else {
        final page = await repo.list(PageRequest(), status: status);
        if (!mounted) return;
        setState(() {
          filtered = page.items;
          filteredNext = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadMoreFiltered() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .list(PageRequest(after: filteredNext), status: status);
      if (mounted) {
        setState(() {
          filtered = [...filtered, ...page.items];
          filteredNext = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadMoreSection(String section) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      if (section == 'new') {
        final page = await repo.list(
          PageRequest(after: newsNext),
          status: 'new',
        );
        if (mounted) {
          setState(() {
            news = [...news, ...page.items];
            newsNext = page.next;
          });
        }
      } else if (section == 'done') {
        final page = await repo.list(
          PageRequest(after: donesNext),
          status: 'done',
        );
        if (mounted) {
          setState(() {
            dones = [...dones, ...page.items];
            donesNext = page.next;
          });
        }
      } else {
        final page = await repo.listByStatuses(
          PageRequest(after: othersNext),
          statuses: _otherStatuses,
        );
        if (mounted) {
          setState(() {
            others = [...others, ...page.items];
            othersNext = page.next;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> withdraw(Ticket t) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmAction(
      context,
      'Видалити звернення?',
      'Звернення буде видалено остаточно разом з історією й вкладеннями. Відновити його буде неможливо.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(supportRepositoryProvider).purgeNewTicket(t);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Звернення видалено остаточно.')),
      );
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget ticketCard(Ticket t) {
    final isAdmin =
        ref.watch(profileProvider).asData?.value?.role == UserRole.admin;
    return Card(
      child: AppLinkTap(
        to: '/support/${t.id}',
        builder: (context, onTap) => ListTile(
          title: Text(t.title),
          subtitle: Text(
            '${ticketStatusLabel(t.status)} · ${priorityLabel(t.priority)} · ${localDate(t.lastActivityAt)}',
          ),
          onTap: onTap,
          trailing: isAdmin && t.status == 'new'
              ? IconButton(
                  tooltip: 'Видалити звернення',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy ? null : () => withdraw(t),
                )
              : null,
        ),
      ),
    );
  }

  Widget sectionBlock({
    required String title,
    required List<Ticket> items,
    required PageCursor? next,
    required String sectionKey,
    required String empty,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (items.isEmpty) Text(empty),
      for (final t in items) ticketCard(t),
      if (next != null)
        TextButton(
          onPressed: busy ? null : () => loadMoreSection(sectionKey),
          child: const Text('Завантажити ще'),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Звернення',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Звернення бачать адміністрація та розробник. Сюди також потрапляють «Зауваження та пропозиції» від користувачів. '
          'Без фільтра спочатку нові, далі виконані, потім інші статуси.',
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
                      reload();
                    },
              items: [
                const DropdownMenuItem(value: null, child: Text('Усі статуси')),
                for (final s in ticketStatuses)
                  DropdownMenuItem(value: s, child: Text(ticketStatusLabel(s))),
              ],
            ),
            TextButton(
              onPressed: busy ? null : reload,
              child: const Text('Оновити'),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Problem(error!, retry: reload),
        if (!busy && error == null && allSections) ...[
          sectionBlock(
            title: 'Нові',
            items: news,
            next: newsNext,
            sectionKey: 'new',
            empty: 'Нових звернень немає.',
          ),
          sectionBlock(
            title: 'Виконано',
            items: dones,
            next: donesNext,
            sectionKey: 'done',
            empty: 'Немає виконаних звернень.',
          ),
          sectionBlock(
            title: 'Інші',
            items: others,
            next: othersNext,
            sectionKey: 'other',
            empty: 'Немає звернень в інших статусах.',
          ),
        ],
        if (!busy && error == null && !allSections) ...[
          if (filtered.isEmpty) const Text('Звернень з цим статусом немає.'),
          for (final t in filtered) ticketCard(t),
          if (filteredNext != null)
            TextButton(
              onPressed: busy ? null : loadMoreFiltered,
              child: const Text('Завантажити ще'),
            ),
        ],
      ],
    ),
  );
}

/// Public feedback form for organizers and admins (`type: feedback`).
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});
  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final title = TextEditingController(), body = TextEditingController();
  final form = GlobalKey<FormState>();
  late final String id;
  bool busy = false;
  bool loadingMine = true;
  Object? error;
  Object? mineError;
  List<Ticket> mine = [];
  PageCursor? mineNext;

  @override
  void initState() {
    super.initState();
    id = ref.read(supportRepositoryProvider).newId();
    Future.microtask(() => loadMine(true));
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> loadMine(bool reset) async {
    setState(() {
      loadingMine = true;
      mineError = null;
      if (reset) {
        mine = [];
        mineNext = null;
      }
    });
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .listMine(PageRequest(after: mineNext));
      if (mounted) {
        setState(() {
          mine = [...mine, ...page.items];
          mineNext = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => mineError = e);
    } finally {
      if (mounted) setState(() => loadingMine = false);
    }
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
          .create(id, type: 'feedback', title: title.text, body: body.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Дякуємо! Зауваження надіслано. Відповідь з’явиться в коментарях на цій сторінці.',
          ),
        ),
      );
      context.go('/support/$id');
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Зауваження та пропозиції',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Опишіть зауваження або ідею покращення. Після надсилання ви '
                'побачите звернення тут; відповідь адміністрації з’явиться в '
                'коментарях.',
              ),
              const SizedBox(height: 16),
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
                child: Text(busy ? 'Надсилання…' : 'Надіслати'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Мої зауваження', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Тут зберігаються ваші надіслані звернення. Відкрийте, щоб побачити '
          'статус і відповідь у коментарях.',
        ),
        const SizedBox(height: 12),
        if (loadingMine) const LinearProgressIndicator(),
        if (mineError != null)
          Problem(mineError!, retry: () => loadMine(true)),
        if (!loadingMine && mineError == null && mine.isEmpty)
          const Text('Ви ще не надсилали зауважень.'),
        for (final t in mine)
          Card(
            child: AppLinkTap(
              to: '/support/${t.id}',
              builder: (context, onTap) => ListTile(
                title: Text(t.title),
                subtitle: Text(
                  '${ticketStatusLabel(t.status)} · ${localDate(t.lastActivityAt)}',
                ),
                onTap: onTap,
              ),
            ),
          ),
        if (mineNext != null)
          TextButton(
            onPressed: loadingMine ? null : () => loadMine(false),
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
  final pendingPhotos = <({String name, String type, Uint8List bytes})>[];
  @override
  void initState() {
    super.initState();
    id = ref.read(supportRepositoryProvider).newId();
    final draft = loadSupportDraft();
    if (draft != null) {
      type = draft.type;
      title.text = draft.title;
      body.text = draft.body;
    }
    title.addListener(_persistDraft);
    body.addListener(_persistDraft);
  }

  void _persistDraft() =>
      saveSupportDraft(type: type, title: title.text, body: body.text);

  @override
  void dispose() {
    title.removeListener(_persistDraft);
    body.removeListener(_persistDraft);
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> pickPhotos() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      error = null;
    });
    for (final file in files) {
      if (pendingPhotos.length >= maxAttachmentsPerTicket) break;
      final bytes = await file.readAsBytes();
      if (!mounted || bytes.isEmpty) continue;
      final lower = file.name.toLowerCase();
      final contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      if (bytes.length > maxAttachmentBytes) {
        if (mounted) await showPhotoTooLargeDialog(context);
        continue;
      }
      setState(
        () => pendingPhotos.add((
          name: file.name,
          type: contentType,
          bytes: bytes,
        )),
      );
    }
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.create(id, type: type, title: title.text, body: body.text);
      clearSupportDraft();
      for (final photo in pendingPhotos) {
        await repo.addAttachment(
          id,
          fileName: photo.name,
          contentType: photo.type,
          bytes: photo.bytes,
        );
      }
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
            onChanged: busy
                ? null
                : (v) {
                    type = v!;
                    _persistDraft();
                  },
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
            decoration: const InputDecoration(
              labelText: 'Опис',
              helperText: 'Чорнетка зберігається в цьому браузері, навіть якщо відволіктися.',
            ),
            validator: (v) => (v?.trim().runes.length ?? 0) < 10
                ? 'Щонайменше 10 символів'
                : null,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy || pendingPhotos.length >= maxAttachmentsPerTicket
                ? null
                : pickPhotos,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              'Додати фото (${pendingPhotos.length}/$maxAttachmentsPerTicket)',
            ),
          ),
          const Text('JPEG, PNG або WebP до 700 КБ кожне.'),
          if (pendingPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < pendingPhotos.length; i++)
                  Stack(
                    children: [
                      CopyFriendlyImage(
                        bytes: pendingPhotos[i].bytes,
                        fileName: pendingPhotos[i].name,
                        contentType: pendingPhotos[i].type,
                        width: 96,
                        height: 96,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          tooltip: 'Прибрати',
                          onPressed: busy
                              ? null
                              : () => setState(() => pendingPhotos.removeAt(i)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (error != null) Problem(error!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Збереження…' : 'Створити звернення'),
          ),
          TextButton(
            onPressed: busy ? null : () => context.go('/support'),
            child: const Text('До списку звернень'),
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
  List<SupportEntry> comments = [], history = [], attachments = [];
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
      final repo = ref.read(supportRepositoryProvider);
      final t = await repo.get(widget.id);
      var nextComments = <SupportEntry>[];
      var nextHistory = <SupportEntry>[];
      var nextAttachments = <SupportEntry>[];
      PageCursor? nextCommentCursor, nextHistoryCursor;
      Object? sideError;
      if (t != null) {
        try {
          final c = await repo.entries(widget.id, 'comments', PageRequest());
          nextComments = c.items;
          nextCommentCursor = c.next;
        } catch (e) {
          sideError ??= e;
        }
        try {
          final h = await repo.entries(widget.id, 'history', PageRequest());
          nextHistory = h.items;
          nextHistoryCursor = h.next;
        } catch (e) {
          sideError ??= e;
        }
        try {
          final a = await repo.entries(widget.id, 'attachments', PageRequest());
          nextAttachments = a.items;
        } catch (e) {
          sideError ??= e;
        }
      }
      if (mounted) {
        setState(() {
          ticket = t;
          comments = nextComments;
          history = nextHistory;
          attachments = nextAttachments;
          commentNext = nextCommentCursor;
          historyNext = nextHistoryCursor;
          error = sideError;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(
    Future<void> Function(SupportRepository, Ticket) action, {
    String? successMessage,
  }) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action(ref.read(supportRepositoryProvider), ticket!);
      comment.clear();
      await load();
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> askReopenReason() async {
    final reason = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Відкрити повторно'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: reason,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Причина повторного відкриття',
              helperText: 'Обов’язково поясніть, що саме лишилося невирішеним.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () {
              final text = reason.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('Відкрити повторно'),
          ),
        ],
      ),
    );
    reason.dispose();
    return result;
  }

  Future<void> addPhotos() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      for (final file in files) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        if (bytes.length > maxAttachmentBytes) {
          if (mounted) await showPhotoTooLargeDialog(context);
          continue;
        }
        final lower = file.name.toLowerCase();
        final contentType = lower.endsWith('.png')
            ? 'image/png'
            : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
        await repo.addAttachment(
          widget.id,
          fileName: file.name,
          contentType: contentType,
          bytes: bytes,
        );
      }
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

  Uint8List? attachmentBytes(SupportEntry entry) {
    final raw = entry.data['bytes'];
    if (raw is Blob) return raw.bytes;
    if (raw is Uint8List) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ticket,
        role = ref.watch(profileProvider).asData?.value?.role.name ?? '';
    final isStaff = role == 'admin' || role == 'developer';
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
            const SizedBox(height: 8),
            Text(
              !isStaff
                  ? 'Це ваше звернення. Відповідь адміністрації з’явиться нижче в коментарях. Статус змінює лише команда Дачі.'
                  : switch (t.status) {
                      'accepted' =>
                        '«Очікує роботи» означає, що розробник прийняв звернення. Це не схвалення події. Після перевірки натисніть «Закрити».',
                      'done' =>
                        'Роботу позначено виконаною. Якщо все гаразд — натисніть «Закрити». Якщо ні — «Відкрити повторно».',
                      'new' =>
                        role == 'admin'
                            ? 'Нове звернення. Помилкове можна прибрати кнопкою «Видалити». Команда «Закрити» з’явиться після виконання.'
                            : 'Нове звернення чекає на розробника.',
                      _ =>
                        'Статус у рядку вище — поточний стан. Кнопки нижче — дії (наприклад «Закрити»), а не назви статусів.',
                    },
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(t.body),
            const SizedBox(height: 16),
            Text('Фото', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (attachments.isEmpty) const Text('Фото ще не додані.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in attachments)
                  if (attachmentBytes(a) case final bytes?)
                    Tooltip(
                      message: '${a.data['fileName']}',
                      child: CopyFriendlyImage(
                        bytes: bytes,
                        fileName: '${a.data['fileName'] ?? 'photo.jpg'}',
                        contentType: '${a.data['contentType'] ?? 'image/jpeg'}',
                        width: 140,
                        height: 140,
                      ),
                    ),
              ],
            ),
            if (isStaff)
              OutlinedButton.icon(
                onPressed: busy || attachments.length >= maxAttachmentsPerTicket
                    ? null
                    : addPhotos,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  'Додати фото (${attachments.length}/$maxAttachmentsPerTicket)',
                ),
              ),
            if (isStaff) ...[
              const Divider(height: 32),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 8,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Коментар',
                  helperText:
                      'Звичайні уточнення. Причину повторного відкриття запитає окреме вікно кнопки «Відкрити повторно».',
                ),
              ),
              if (role == 'admin' && t.status == 'new')
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Помилкове або тестове звернення зі статусом «Нове» можна прибрати кнопкою Видалити — запис знищується остаточно. Також є іконка кошика в списку звернень.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (isStaff)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => act((r, t) => r.comment(t, comment.text)),
                    child: const Text('Додати коментар'),
                  ),
                if (isStaff && role == 'admin' && t.status == 'new')
                  FilledButton.tonalIcon(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!await confirmAction(
                              context,
                              'Видалити звернення?',
                              'Звернення буде видалено остаточно разом з історією й вкладеннями. Відновити його буде неможливо.',
                            )) {
                              return;
                            }
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(supportRepositoryProvider)
                                  .purgeNewTicket(t);
                              if (!mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              final router = GoRouter.of(context);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Звернення видалено остаточно.',
                                  ),
                                ),
                              );
                              router.go('/support');
                            } catch (e) {
                              if (mounted) setState(() => error = e);
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Видалити'),
                  ),
                if (isStaff && role == 'admin' && t.status == 'new')
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final titleCtrl = TextEditingController(
                              text: t.title,
                            );
                            final bodyCtrl = TextEditingController(
                              text: t.body,
                            );
                            var editType = t.type;
                            final saved = await showDialog<bool>(
                              context: context,
                              builder: (context) => StatefulBuilder(
                                builder: (context, setDialogState) =>
                                    AlertDialog(
                                  title: const Text('Редагувати звернення'),
                                  content: SizedBox(
                                    width: 480,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          initialValue: editType,
                                          decoration: const InputDecoration(
                                            labelText: 'Тип',
                                          ),
                                          items: [
                                            for (final type in ticketTypes)
                                              DropdownMenuItem(
                                                value: type,
                                                child: Text(typeLabel(type)),
                                              ),
                                          ],
                                          onChanged: (value) {
                                            if (value == null) return;
                                            setDialogState(
                                              () => editType = value,
                                            );
                                          },
                                        ),
                                        TextField(
                                          controller: titleCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Тема',
                                          ),
                                          maxLength: 160,
                                        ),
                                        TextField(
                                          controller: bodyCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Опис',
                                          ),
                                          minLines: 4,
                                          maxLines: 10,
                                          maxLength: 10000,
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Скасувати'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Зберегти'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (saved == true) {
                              await act(
                                (r, ticket) => r.editContent(
                                  ticket,
                                  title: titleCtrl.text,
                                  body: bodyCtrl.text,
                                  type: editType,
                                ),
                              );
                            }
                            titleCtrl.dispose();
                            bodyCtrl.dispose();
                          },
                    child: const Text('Редагувати'),
                  ),
                if (isStaff)
                  for (final status in allowedTicketStatuses(role, t.status))
                    Builder(
                      builder: (context) {
                        final reopening =
                            status == 'new' &&
                            ['done', 'rejected', 'closed'].contains(t.status);
                        final label = reopening
                            ? 'Відкрити повторно'
                            : status == 'closed'
                            ? 'Закрити'
                            : status == 'accepted'
                            ? 'Прийняти в роботу'
                            : status == 'in_progress'
                            ? 'Взяти в роботу'
                            : status == 'done'
                            ? 'Позначити виконаним'
                            : status == 'rejected'
                            ? 'Відхилити'
                            : ticketStatusLabel(status);
                        Future<void> onPressed() async {
                          if (reopening) {
                            final reason = await askReopenReason();
                            if (reason == null || !mounted) return;
                            await act(
                              (r, ticket) =>
                                  r.status(ticket, status, comment: reason),
                              successMessage:
                                  'Звернення знову відкрито зі статусом «Нове».',
                            );
                            return;
                          }
                          if (await confirmAction(
                            context,
                            status == 'closed'
                                ? 'Закрити звернення?'
                                : 'Змінити статус?',
                            status == 'closed'
                                ? 'Після перевірки звернення можна закрити. Статус стане «Закрито».'
                                : label,
                          )) {
                            await act(
                              (r, ticket) => r.status(
                                ticket,
                                status,
                                comment: comment.text.trim().isEmpty
                                    ? null
                                    : comment.text,
                              ),
                            );
                          }
                        }

                        return OutlinedButton(
                          onPressed: busy ? null : onPressed,
                          child: Text(label),
                        );
                      },
                    ),
                if (isStaff && role == 'developer')
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
                TextButton(
                  onPressed: busy
                      ? null
                      : () => context.go(isStaff ? '/support' : '/feedback'),
                  child: Text(
                    isStaff ? 'До списку звернень' : 'До моїх зауважень',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              isStaff ? 'Коментарі' : 'Відповіді',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (comments.isEmpty)
              Text(
                isStaff
                    ? 'Коментарів поки немає.'
                    : 'Відповіді ще немає. Адміністрація відповість у коментарях.',
              ),
            for (final c in comments)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          c.data['authorRole'] == 'admin'
                              ? 'Адміністрація'
                              : 'Розробник',
                          if (supportTimestamp(c.data['createdAt'])
                              case final at?)
                            '${localDate(at)} ${localTime(at)}',
                        ].join(' · '),
                      ),
                      const SizedBox(height: 8),
                      Text('${c.data['body'] ?? ''}'),
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
                    subtitle: Text(historySubtitle(h.data)),
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
