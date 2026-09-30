import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/domain_exception.dart';
import '../../core/time/time_zone_service.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/bookings/domain/booking.dart';
import '../providers.dart';

String errorMessage(Object error) {
  if (error is DomainException) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Перевірте електронну адресу.',
      'email-already-in-use' =>
        'Ця адреса вже зареєстрована. Увійдіть або відновіть пароль.',
      'weak-password' => 'Пароль не відповідає вимогам. Використайте щонайменше 8 символів, літери й цифри.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Не вдалося увійти. Перевірте адресу й пароль.',
      'too-many-requests' => 'Забагато спроб. Спробуйте пізніше.',
      'network-request-failed' => 'Перевірте інтернет-з’єднання.',
      _ => 'Не вдалося виконати дію. Код: ${error.code}.',
    };
  }
  return 'Не вдалося завантажити або зберегти дані. Спробуйте ще раз.';
}

String localDate(DateTime instant) =>
    DateFormat('dd.MM.yyyy').format(TimeZoneService().toKyiv(instant));
String localTime(DateTime instant) =>
    DateFormat('HH:mm').format(TimeZoneService().toKyiv(instant));
String statusLabel(BookingStatus status) => switch (status) {
  BookingStatus.pending => 'Очікує рішення',
  BookingStatus.approved => 'Схвалено',
  BookingStatus.rejected => 'Відхилено',
  BookingStatus.cancelled => 'Скасовано',
};

class AppFrame extends ConsumerWidget {
  const AppFrame({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final profile = ref.watch(profileProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: () => context.go('/'),
          child: const Text(
            'Дача',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Меню',
            onSelected: (route) async {
              if (route == 'logout') {
                try {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/');
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMessage(error))),
                    );
                  }
                }
              } else {
                context.go(route);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '/', child: Text('Розклад')),
              const PopupMenuItem(value: '/rooms', child: Text('Локації')),
              if (profile == null ||
                  (!profile.isDisabled && profile.role != UserRole.developer))
                PopupMenuItem(
                  value: profile?.role == UserRole.admin
                      ? '/admin/events/new'
                      : '/bookings/new',
                  child: const Text('Забронювати'),
                ),
              if (profile != null &&
                  !profile.isDisabled &&
                  profile.role != UserRole.developer)
                const PopupMenuItem(
                  value: '/my-bookings',
                  child: Text('Мої заявки'),
                ),
              if (profile?.role == UserRole.admin && !profile!.isDisabled)
                const PopupMenuItem(value: '/admin', child: Text('Керування')),
              if (profile != null &&
                  !profile.isDisabled &&
                  profile.role != UserRole.organizer)
                const PopupMenuItem(
                  value: '/support',
                  child: Text('Написати розробнику'),
                ),
              PopupMenuItem(
                value: session == null ? '/login' : '/account',
                child: Text(session == null ? 'Увійти' : 'Обліковий запис'),
              ),
              if (session != null)
                const PopupMenuItem(value: 'logout', child: Text('Вийти')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    child,
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Problem extends StatelessWidget {
  const Problem(this.error, {super.key, this.retry});
  final Object error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        errorMessage(error),
        semanticsLabel: 'Помилка: ${errorMessage(error)}',
      ),
      if (retry != null)
        TextButton(onPressed: retry, child: const Text('Спробувати ще')),
    ],
  );
}

class ProtectedPage extends ConsumerWidget {
  const ProtectedPage({
    super.key,
    required this.child,
    this.roles = const [UserRole.organizer, UserRole.admin, UserRole.developer],
  });
  final Widget child;
  final List<UserRole> roles;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider),
        profile = ref.watch(profileProvider);
    if (session.isLoading) {
      return const AppFrame(
        title: 'Завантаження',
        child: LinearProgressIndicator(),
      );
    }
    if (session.hasError) {
      return AppFrame(title: 'Помилка входу', child: Problem(session.error!));
    }
    if (session.asData?.value == null) {
      return AppFrame(
        title: 'Потрібен вхід',
        child: FilledButton(
          onPressed: () => context.go(
            '/login?returnTo=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
          ),
          child: const Text('Увійти'),
        ),
      );
    }
    if (profile.isLoading) {
      return const AppFrame(
        title: 'Завантаження профілю',
        child: LinearProgressIndicator(),
      );
    }
    if (profile.hasError) {
      return AppFrame(
        title: 'Помилка профілю',
        child: Problem(
          profile.error!,
          retry: () => ref.invalidate(profileProvider),
        ),
      );
    }
    final user = profile.asData?.value;
    if (user == null) {
      return AppFrame(
        title: 'Завершіть створення профілю',
        child: FilledButton(
          onPressed: () => context.go('/account'),
          child: const Text('Відновити профіль'),
        ),
      );
    }
    if (user.isDisabled) {
      return const AppFrame(
        title: 'Обліковий запис заблоковано',
        child: Text('Зверніться до адміністрації Дачі.'),
      );
    }
    if (!roles.contains(user.role)) {
      return const AppFrame(
        title: 'Немає доступу',
        child: Text('Ця сторінка недоступна для вашої ролі.'),
      );
    }
    return KeyedSubtree(key: ValueKey(user.id), child: child);
  }
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Підтвердити'),
          ),
        ],
      ),
    ) ??
    false;

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.action,
    this.outlined = false,
  });
  final String label;
  final Future<void> Function() action;
  final bool outlined;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  Future<void> run() async {
    setState(() => busy = true);
    try {
      await widget.action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(busy ? 'Зачекайте…' : widget.label);
    return widget.outlined
        ? OutlinedButton(onPressed: busy ? null : run, child: label)
        : FilledButton(onPressed: busy ? null : run, child: label);
  }
}
