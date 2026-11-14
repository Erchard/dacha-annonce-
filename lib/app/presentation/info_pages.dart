import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/web/share_actions.dart';
import '../../core/widgets/app_link.dart';
import '../../features/auth/domain/user_profile.dart';
import '../providers.dart';
import 'shared.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> body) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.titleLarge),
          const SizedBox(height: 8),
          ...body,
        ],
      ),
    );

    return AppFrame(
      title: 'Інструкція',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Це коротка інструкція, як користуватися сайтом «Дача». '
            'Читайте по кроках.',
            style: theme.bodyLarge,
          ),
          const SizedBox(height: 24),
          section('Розділи сайту', [
            const Text(
              '1. Календар — подивіться події за день, тиждень або місяць. '
              'На телефоні в місяці видно назви подій у клітинках; '
              'натисніть день, щоб побачити подробиці. '
              'Поруч є кнопка «Розклад» — вона відкриває розклад на місяць.',
            ),
            const SizedBox(height: 8),
            const Text(
              '2. Розклад — таблиця майбутніх подій. Тут можна обрати локацію '
              'і напрямки.',
            ),
            const SizedBox(height: 8),
            const Text('3. Архів подій — минулі зустрічі.'),
            const SizedBox(height: 8),
            const Text('4. Локації — опис просторів і найближчі події.'),
            const SizedBox(height: 8),
            const AppLink(to: '/', child: Text('Календар')),
            const AppLink(to: '/schedule', child: Text('Розклад')),
            const AppLink(to: '/archive', child: Text('Архів подій')),
          ]),
          section('Реєстрація та вхід', [
            const Text('1. Натисніть «Увійти», потім оберіть реєстрацію.'),
            const SizedBox(height: 8),
            const Text(
              '2. Вкажіть свою електронну пошту і пароль. '
              'Пароль можна показати іконкою ока біля поля.',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. На пошту, яку ви вказали при реєстрації, прийде лист. '
              'Відкрийте його і підтвердіть адресу. '
              'Якщо листа немає у «Вхідних», обов’язково перевірте «Спам».',
            ),
            const SizedBox(height: 8),
            const Text(
              '4. Після підтвердження увійдіть на сайт. '
              'Щоб самостійно публікувати події, потрібен дозвіл адміністратора.',
            ),
            const SizedBox(height: 8),
            const Text(
              '5. Якщо забули пароль — відкрийте сторінку відновлення пароля.',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/register', child: Text('Зареєструватися')),
            const AppLink(to: '/login', child: Text('Увійти')),
            const AppLink(
              to: '/reset-password',
              child: Text('Відновити пароль'),
            ),
          ]),
          section('Заявки на події', [
            const Text('1. Натисніть «Створити подію».'),
            const SizedBox(height: 8),
            const Text(
              '2. Оберіть локацію, дату й час (час — Київ), напишіть назву '
              'і опис, відповідального. За потреби додайте телефон і примітки.',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Заповніть списки: умови участі, статус події (зазвичай '
              '«Заплановано»), основний напрям, формат і цільову групу. '
              'У цільовій групі можна обрати кілька варіантів або «Усі охочі».',
            ),
            const SizedBox(height: 8),
            const Text(
              '4. Звичайна заявка чекає рішення адміністрації. '
              'Якщо вам дали дозвіл самостійної публікації і час вільний — '
              'подію можна опублікувати одразу.',
            ),
            const SizedBox(height: 8),
            const Text(
              '5. Щотижневі серії створює адміністрація '
              '(або організатор із дозволом) як набір окремих подій. '
              'Одне повторення можна перенести, скасувати або видалити '
              'без зміни всієї серії.',
            ),
            const SizedBox(height: 8),
            const AppLink(
              to: '/bookings/new',
              child: Text('Створити подію'),
            ),
          ]),
          section('Напрямки в розкладі', [
            const Text('1. Відкрийте Розклад.'),
            const SizedBox(height: 8),
            const Text(
              '2. У фільтрі «Події за напрямками» оберіть один або кілька '
              'основних напрямів.',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Показуються події з обраним основним напрямом.',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/schedule', child: Text('Відкрити розклад')),
          ]),
          section('Фото', [
            const Text(
              '1. На формі події можна додати одне фото обкладинки.',
            ),
            const SizedBox(height: 8),
            const Text(
              '2. До звернення в підтримці можна додати до п’яти зображень.',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Підходять формати JPEG, PNG або WebP. '
              'Кожен файл — не більше 700 КБ.',
            ),
            const SizedBox(height: 8),
            const Text(
              '4. Якщо файл більший, з’явиться вікно «Фото завелике». '
              'Стисніть зображення і спробуйте знову.',
            ),
          ]),
          section('Контакти й зворотний зв’язок', [
            const Text(
              '1. Контакти простору — на окремій сторінці «Контакти».',
            ),
            const SizedBox(height: 8),
            const Text(
              '2. Зауваження щодо сайту надішліть через «Зауваження та пропозиції» '
              '(потрібен вхід організатора або адміністратора).',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Після надсилання відкриється ваше звернення. '
              'Відповідь з’явиться в коментарях у «Мої зауваження».',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/contacts', child: Text('Контакти')),
            const AppLink(
              to: '/feedback',
              child: Text('Зауваження та пропозиції'),
            ),
          ]),
          section('Ярлик на телефон (не Google Play)', [
            const Text(
              '1. «Дача» — це вебсайт. Окремої програми в Google Play немає.',
            ),
            const SizedBox(height: 8),
            const Text(
              '2. На Android у Chrome відкрийте меню ⋮ і оберіть '
              '«Додати на головний екран» або «Встановити додаток».',
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Це ярлик сайту через браузер, а не програма з магазину.',
            ),
            const SizedBox(height: 8),
            const Text(
              '4. Якщо Google Play Захист попереджає про «старішу версію Android» — '
              'скасуйте встановлення з магазину й додайте ярлик лише з меню Chrome.',
            ),
          ]),
        ],
      ),
    );
  }
}

class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  static const phoneDisplay = '099-343-08-38';
  static const phoneTel = 'tel:+380993430838';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).asData?.value;
    final staff = profile != null &&
        !profile.isDisabled &&
        (profile.role == UserRole.admin || profile.role == UserRole.developer);

    return AppFrame(
      title: 'Контакти',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Зв’язок щодо життя простору «Дача».',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text('М. Кириленко', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openExternalUrl(phoneTel),
              icon: const Icon(Icons.phone),
              label: const Text(phoneDisplay),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Зауваження щодо роботи сайту можна надіслати через форму зворотного зв’язку.',
          ),
          const SizedBox(height: 8),
          const AppLink(
            to: '/feedback',
            child: Text('Зауваження та пропозиції'),
          ),
          if (staff) ...[
            const SizedBox(height: 8),
            const AppLink(to: '/support', child: Text('Звернення (службові)')),
          ],
          const SizedBox(height: 16),
          const AppLink(to: '/help', child: Text('Інструкція користувача')),
        ],
      ),
    );
  }
}
