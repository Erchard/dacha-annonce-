import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/domain_exception.dart';
import '../providers.dart';
import 'shared.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    this.returnTo,
    this.registerInitially = false,
    this.resetOnly = false,
  });
  final String? returnTo;
  final bool registerInitially, resetOnly;
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    register = widget.registerInitially;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  String get destination {
    final path = widget.returnTo;
    return path != null &&
            path.startsWith('/') &&
            !path.startsWith('//') &&
            !path.startsWith('/login')
        ? path
        : '/';
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (register) {
        await auth.register(email.text, password.text, name.text);
      } else {
        await auth.signIn(email.text, password.text);
      }
      if (mounted) context.go(register ? '/account' : destination);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: widget.resetOnly
        ? 'Відновити пароль'
        : register
        ? 'Створити обліковий запис'
        : 'Увійти на Дачу',
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 460,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (register)
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ваше ім’я'),
                  maxLength: 80,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'Укажіть ім’я (від 2 символів).'
                      : null,
                ),
              TextFormField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: 'Електронна адреса',
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => v == null || !v.contains('@')
                    ? 'Укажіть електронну адресу.'
                    : null,
              ),
              const SizedBox(height: 16),
              if (!widget.resetOnly)
                TextFormField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!busy) submit();
                  },
                  validator: (v) => v == null || v.isEmpty
                      ? 'Укажіть пароль.'
                      : register &&
                            (v.length < 8 ||
                                !RegExp(r'[0-9]').hasMatch(v) ||
                                !RegExp(r'[A-Za-zА-Яа-яІіЇїЄє]').hasMatch(v))
                      ? 'Щонайменше 8 символів, літери й цифри.'
                      : null,
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (!widget.resetOnly)
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Зачекайте…'
                        : register
                        ? 'Зареєструватися'
                        : 'Увійти',
                  ),
                ),
              if (!widget.resetOnly)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = !register;
                          error = null;
                        }),
                  child: Text(
                    register
                        ? 'Уже є обліковий запис? Увійти'
                        : 'Створити обліковий запис',
                  ),
                ),
              if (!register)
                ActionButton(
                  label: 'Відновити пароль',
                  outlined: true,
                  action: () async {
                    if (!email.text.contains('@')) {
                      throw const DomainException(
                        ErrorCode.validation,
                        field: 'email',
                      );
                    }
                    await ref
                        .read(authRepositoryProvider)
                        .resetPassword(email.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Якщо адреса зареєстрована, ви отримаєте лист для відновлення пароля.',
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});
  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final name = TextEditingController();
  DateTime? sentAt;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider),
        profile = ref.watch(profileProvider);
    if (session.isLoading || profile.isLoading) {
      return const AppFrame(
        title: 'Обліковий запис',
        child: LinearProgressIndicator(),
      );
    }
    if (session.hasError || profile.hasError) {
      return AppFrame(
        title: 'Обліковий запис',
        child: Problem(session.error ?? profile.error!),
      );
    }
    final auth = session.asData?.value, user = profile.asData?.value;
    if (auth == null) {
      return AppFrame(
        title: 'Обліковий запис',
        child: FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Увійти'),
        ),
      );
    }
    return AppFrame(
      title: user == null ? 'Відновлення профілю' : 'Обліковий запис',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) Text('Вітаємо, ${user.displayName}!'),
          if (user?.isDisabled == true)
            const Text(
              'Обліковий запис заблоковано. Зверніться до адміністрації.',
            ),
          if (user == null)
            const Text(
              'Вхід уже створено, але профіль не зберігся. Укажіть ім’я, щоб завершити реєстрацію.',
            ),
          if (user?.isDisabled != true) ...[
            SizedBox(
              width: 460,
              child: TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: user == null ? 'Ваше ім’я' : 'Нове ім’я',
                  hintText: user?.displayName,
                ),
                maxLength: 80,
              ),
            ),
            ActionButton(
              label: user == null ? 'Створити профіль' : 'Зберегти ім’я',
              action: () => user == null
                  ? ref.read(authRepositoryProvider).recoverProfile(name.text)
                  : ref.read(repositoryProvider).updateMyDisplayName(name.text),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            auth.emailVerified
                ? 'Електронну адресу підтверджено.'
                : 'Підтвердьте електронну адресу перед поданням заявки.',
          ),
          if (!auth.emailVerified)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ActionButton(
                  label: 'Надіслати лист підтвердження',
                  action: () async {
                    if (sentAt != null &&
                        DateTime.now().difference(sentAt!) <
                            const Duration(seconds: 60)) {
                      throw const DomainException(
                        ErrorCode.validation,
                        field: 'resendCooldown',
                      );
                    }
                    await ref.read(authRepositoryProvider).sendVerification();
                    sentAt = DateTime.now();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Лист надіслано. Повторне надсилання доступне через хвилину.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ActionButton(
                  label: 'Я підтвердив адресу',
                  outlined: true,
                  action: () => ref.read(authRepositoryProvider).reloadUser(),
                ),
              ],
            ),
          const SizedBox(height: 24),
          ActionButton(
            label: 'Вийти',
            outlined: true,
            action: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }
}
