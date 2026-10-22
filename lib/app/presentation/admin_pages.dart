import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/page.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/rooms/domain/room.dart';
import '../providers.dart';
import 'shared.dart';

class AdminRoomsPage extends ConsumerStatefulWidget {
  const AdminRoomsPage({super.key});
  @override
  ConsumerState<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends ConsumerState<AdminRoomsPage> {
  List<Room> rooms = [];
  String? deleteErrorRoomId;
  Object? deleteError;
  PageCursor? next;
  Object? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(reset: true));
  }

  Future<void> load({required bool reset}) async {
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        rooms = [];
        next = null;
      }
    });
    try {
      final page = await ref
          .read(repositoryProvider)
          .listRooms(PageRequest(after: next), activeOnly: false);
      if (mounted) {
        setState(() {
          rooms = [...rooms, ...page.items];
          next = page.next;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Room? room) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _RoomEditor(room: room),
    );
    if (saved == true && mounted) await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Локації',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          children: [
            FilledButton(
              onPressed: () => edit(null),
              child: const Text('Додати локацію'),
            ),
            TextButton(
              onPressed: () => context.go('/admin'),
              child: const Text('До керування'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (error != null)
          Problem(error!, retry: () => load(reset: rooms.isEmpty)),
        if (busy) const LinearProgressIndicator(),
        if (!busy && error == null && rooms.isEmpty)
          const Text('Додайте першу локацію, щоб приймати заявки.'),
        for (final room in rooms)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    room.isActive ? 'Доступна для нових заявок' : 'В архіві',
                  ),
                  Text(room.locationLabel),
                  if (deleteErrorRoomId == room.id && deleteError != null)
                    Problem(deleteError!),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => edit(room),
                        child: const Text('Редагувати'),
                      ),
                      if (!room.isActive)
                        ActionButton(
                          label: 'Видалити',
                          outlined: true,
                          action: () async {
                            if (!await confirmAction(
                              context,
                              'Видалити локацію?',
                              'Локація зникне зі списків без можливості відновлення. Якщо це тимчасове закриття, залиште її в архіві. Локацію із заявками або схваленими подіями спочатку потрібно звільнити.',
                            )) {
                              return;
                            }
                            setState(() {
                              deleteErrorRoomId = null;
                              deleteError = null;
                            });
                            try {
                              await ref
                                  .read(repositoryProvider)
                                  .deleteRoom(room);
                              if (mounted) await load(reset: true);
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  deleteErrorRoomId = room.id;
                                  deleteError = e;
                                });
                              }
                            }
                          },
                        ),
                      if (room.isActive)
                        ActionButton(
                          label: 'Архівувати',
                          outlined: true,
                          action: () async {
                            if (!await confirmAction(
                              context,
                              'Архівувати локацію?',
                              'Нові заявки будуть недоступні. Уже схвалені події залишаться в розкладі.',
                            )) {
                              return;
                            }
                            await ref
                                .read(repositoryProvider)
                                .archive(
                                  room.id,
                                  expectedRevision: room.revision,
                                );
                            if (mounted) await load(reset: true);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (next != null)
          OutlinedButton(
            onPressed: busy ? null : () => load(reset: false),
            child: const Text('Завантажити ще'),
          ),
      ],
    ),
  );
}

class _RoomEditor extends ConsumerStatefulWidget {
  const _RoomEditor({this.room});
  final Room? room;
  @override
  ConsumerState<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends ConsumerState<_RoomEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, location, capacity, order;
  late final String id;
  late bool active;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final room = widget.room;
    name = TextEditingController(text: room?.name);
    description = TextEditingController(text: room?.description);
    location = TextEditingController(text: room?.locationLabel);
    capacity = TextEditingController(text: room?.capacity?.toString());
    order = TextEditingController(text: '${room?.sortOrder ?? 0}');
    active = room?.isActive ?? true;
    id = room?.id ?? ref.read(repositoryProvider).newRoomId();
  }

  @override
  void dispose() {
    for (final controller in [name, description, location, capacity, order]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final old = widget.room, now = DateTime.now().toUtc();
      await ref
          .read(repositoryProvider)
          .upsert(
            Room(
              id: id,
              name: name.text.trim(),
              description: description.text.trim(),
              locationLabel: location.text.trim(),
              capacity: capacity.text.trim().isEmpty
                  ? null
                  : int.parse(capacity.text.trim()),
              isActive: active,
              sortOrder: int.parse(order.text.trim()),
              createdAt: old?.createdAt ?? now,
              updatedAt: now,
              revision: old?.revision ?? 1,
              lastAuditId: old?.lastAuditId ?? 'new',
            ),
            expectedRevision: old?.revision ?? 0,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.room == null ? 'Нова локація' : 'Редагувати локацію'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Назва'),
                maxLength: 80,
                validator: (v) => (v?.trim().length ?? 0) < 2
                    ? 'Щонайменше 2 символи.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Розташування'),
                maxLength: 160,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Опис'),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: capacity,
                decoration: const InputDecoration(
                  labelText: 'Кількість людей',
                  helperText: 'Одне число, наприклад 20. Необов’язково.',
                  helperMaxLines: 4,
                  errorMaxLines: 5,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final parsed = int.tryParse(text);
                  if (parsed == null || parsed < 1 || parsed > 1000) {
                    return 'Укажіть одне ціле число від 1 до 1000 або залиште поле порожнім.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: order,
                decoration: const InputDecoration(
                  labelText: 'Порядок у списку',
                ),
                keyboardType: TextInputType.text,
                validator: (v) =>
                    int.tryParse(v ?? '') == null ||
                        int.parse(v!) < 0 ||
                        int.parse(v) > 10000
                    ? 'Від 0 до 10000.'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Доступна для заявок'),
                value: active,
                onChanged: busy ? null : (v) => setState(() => active = v),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Назад'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Зберігаємо…' : 'Зберегти'),
      ),
    ],
  );
}

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});
  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  List<UserProfile> users = [];
  PageCursor? next;
  UserRole role = UserRole.organizer;
  bool busy = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(reset: true));
  }

  Future<void> load({required bool reset}) async {
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        users = [];
        next = null;
      }
    });
    try {
      final page = await ref
          .read(repositoryProvider)
          .listProfiles(PageRequest(after: next), role: role);
      if (mounted) {
        setState(() {
          users = [...users, ...page.items];
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
    title: 'Користувачі',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<UserRole>(
          isExpanded: true,
          initialValue: role,
          decoration: const InputDecoration(labelText: 'Роль'),
          items: const [
            DropdownMenuItem(
              value: UserRole.organizer,
              child: Text('Організатори'),
            ),
            DropdownMenuItem(
              value: UserRole.admin,
              child: Text('Адміністратори'),
            ),
            DropdownMenuItem(
              value: UserRole.developer,
              child: Text('Розробники'),
            ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  setState(() => role = value!);
                  load(reset: true);
                },
        ),
        const SizedBox(height: 16),
        if (error != null)
          Problem(error!, retry: () => load(reset: users.isEmpty)),
        if (busy) const LinearProgressIndicator(),
        if (!busy && error == null && users.isEmpty)
          const Text('Користувачів із цією роллю немає.'),
        for (final user in users)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SelectableText(
                    user.id,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    user.isDisabled
                        ? 'Заблоковано'
                        : 'Активний обліковий запис',
                  ),
                  if (user.role == UserRole.organizer)
                    ActionButton(
                      label: user.canPublish
                          ? 'Забрати самостійну публікацію'
                          : 'Дозволити самостійну публікацію',
                      outlined: true,
                      action: () async {
                        if (!await confirmAction(
                          context,
                          'Змінити право публікації?',
                          'Цей організатор зможе публікувати, редагувати, переносити й видаляти власні події без вашого схвалення. Чужі події та адміністративні розділи залишаться недоступними.',
                        )) {
                          return;
                        }
                        await ref
                            .read(repositoryProvider)
                            .setPublishing(
                              user.id,
                              !user.canPublish,
                              expectedRevision: user.adminRevision,
                            );
                        if (mounted) await load(reset: true);
                      },
                    ),
                  if (user.role == UserRole.organizer)
                    ActionButton(
                      label: user.isDisabled ? 'Розблокувати' : 'Заблокувати',
                      outlined: true,
                      action: () async {
                        if (!await confirmAction(
                          context,
                          user.isDisabled
                              ? 'Розблокувати користувача?'
                              : 'Заблокувати користувача?',
                          'Зміниться доступ до приватних дій у застосунку. Історія та події залишаться.',
                        )) {
                          return;
                        }
                        await ref
                            .read(repositoryProvider)
                            .setDisabled(
                              user.id,
                              !user.isDisabled,
                              expectedRevision: user.adminRevision,
                            );
                        if (mounted) await load(reset: true);
                      },
                    ),
                ],
              ),
            ),
          ),
        if (next != null)
          OutlinedButton(
            onPressed: busy ? null : () => load(reset: false),
            child: const Text('Завантажити ще'),
          ),
        TextButton(
          onPressed: () => context.go('/admin'),
          child: const Text('До керування'),
        ),
      ],
    ),
  );
}
