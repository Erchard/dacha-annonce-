import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool register = false, busy = false, rememberMe = true, showPassword = false;
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
      await auth.setRememberSignedIn(rememberMe);
      if (register) {
        await auth.register(email.text, password.text, name.text);
      } else {
        await auth.signIn(email.text, password.text);
      }
      TextInput.finishAutofillContext(shouldSave: rememberMe);
      if (mounted) {
        context.go(
          register ? '/account?registered=1' : destination,
        );
      }
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
        child: AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Перейти на сайт'),
                ),
                const SizedBox(height: 16),
                if (register)
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Ваше ім’я'),
                    maxLength: 80,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
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
                  autofillHints: [
                    if (register)
                      AutofillHints.email
                    else
                      AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Укажіть електронну адресу.'
                      : null,
                ),
                const SizedBox(height: 16),
                if (!widget.resetOnly)
                  TextFormField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      helperText:
                          'Натисніть іконку ока справа, щоб показати або сховати пароль.',
                      suffixIcon: IconButton(
                        tooltip: showPassword
                            ? 'Приховати пароль'
                            : 'Показати пароль',
                        iconSize: 26,
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    obscureText: !showPassword,
                    autofillHints: [
                      if (register)
                        AutofillHints.newPassword
                      else
                        AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
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
                if (!widget.resetOnly)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: rememberMe,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => rememberMe = value ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Запам’ятати мене на цьому комп’ютері'),
                    subtitle: const Text(
                      'Наступного разу вхід без екрана логіну. Браузер також може зберегти пароль.',
                    ),
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
  bool editingName = false;
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
        title: 'Мій профіль',
        child: LinearProgressIndicator(),
      );
    }
    if (session.hasError || profile.hasError) {
      return AppFrame(
        title: 'Мій профіль',
        child: Problem(session.error ?? profile.error!),
      );
    }
    final auth = session.asData?.value, user = profile.asData?.value;
    if (auth == null) {
      return AppFrame(
        title: 'Мій профіль',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Увійдіть, щоб змінити ім’я або вийти з сайту.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Увійти'),
            ),
          ],
        ),
      );
    }
    final justRegistered =
        GoRouterState.of(context).uri.queryParameters['registered'] == '1';
    return AppFrame(
      title: user == null ? 'Завершити реєстрацію' : 'Мій профіль',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (justRegistered) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Обліковий запис створено',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Підтвердіть електронну адресу за посиланням у листі. '
                      'Для самостійного розміщення подій дочекайтесь затвердження адміністратора.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else
            const Text('Тут показано стан вашого облікового запису.'),
          const SizedBox(height: 16),
          if (user != null)
            Text(
              'Вітаємо, ${user.displayName}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          if (user?.isDisabled == true) ...[
            const SizedBox(height: 12),
            const Text(
              'Профіль заблоковано. Зверніться до адміністрації Дачі.',
            ),
          ],
          if (user == null)
            const Text(
              'Вхід успішний, але ім’я ще не збережене. Укажіть його нижче.',
            ),
          if (user != null && !user.isDisabled) ...[
            const SizedBox(height: 12),
            if (!justRegistered)
              const Text(
                'Реєстрацію завершено. Ви увійшли у свій обліковий запис.',
              ),
            if (user.role.name == 'organizer' && !user.canPublish)
              const Text(
                'Для самостійного розміщення подій чекайте на затвердження адміністратора.',
              ),
            if (user.role.name == 'admin' || user.canPublish)
              const Text('Ви можете самостійно публікувати події.'),
            if (!editingName)
              TextButton(
                onPressed: () {
                  name.text = user.displayName;
                  setState(() => editingName = true);
                },
                child: const Text('Змінити ім’я'),
              ),
          ],
          if (user?.isDisabled != true && (user == null || editingName)) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 460,
              child: TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: user == null ? 'Ваше ім’я' : 'Змінити ім’я',
                  hintText: user?.displayName,
                  helperText: 'Це ім’я бачать у розкладі та заявках.',
                ),
                maxLength: 80,
              ),
            ),
            ActionButton(
              label: user == null ? 'Зберегти ім’я' : 'Оновити ім’я',
              action: () => user == null
                  ? ref.read(authRepositoryProvider).recoverProfile(name.text)
                  : ref.read(repositoryProvider).updateMyDisplayName(name.text),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            auth.emailVerified
                ? 'Електронну адресу підтверджено — можна подавати заявки.'
                : 'Обліковий запис уже створений. Щоб подавати заявки, підтвердьте адресу за посиланням у листі. Якщо листа немає, перевірте адресу і спам або зверніться до адміністратора. Доставка листа може затримуватися.',
          ),
          if (!auth.emailVerified)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
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
                              'Лист надіслано. Перевірте скриньку й папку «Спам». '
                              'Повтор через хвилину.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  ActionButton(
                    label: 'Я підтвердив адресу — перевірити',
                    outlined: true,
                    action: () => ref.read(authRepositoryProvider).reloadUser(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          ActionButton(
            label: 'Вийти з сайту',
            outlined: true,
            action: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/schedule');
            },
          ),
        ],
      ),
    );
  }
}
