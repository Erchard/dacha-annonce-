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
            'Короткий огляд сайту «Дача»: як дивитися події, подати заявку й знайти контакти.',
            style: theme.bodyLarge,
          ),
          const SizedBox(height: 24),
          section('Розділи сайту', [
            const Text(
              'Календар — сітка дня, тижня, місяця або список. На телефоні '
              'у місяці видно назви подій у клітинках; натисніть день для деталей. '
              'Розклад — таблиця майбутніх подій (фільтр локації та напрямків). '
              'Архів подій — минулі зустрічі. '
              'Локації — опис просторів і найближчі події.',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/', child: Text('Календар')),
            const AppLink(to: '/schedule', child: Text('Розклад')),
            const AppLink(to: '/archive', child: Text('Архів подій')),
          ]),
          section('Реєстрація та вхід', [
            const Text(
              'Організатори реєструються через «Увійти» → реєстрація, '
              'підтверджують електронну адресу й входять. '
              'Після реєстрації показується підтвердження: обліковий запис створено; '
              'для самостійної публікації подій потрібне затвердження адміністратора. '
              'Пароль можна показати іконкою ока біля поля. '
              'Відновлення пароля — на окремій сторінці.',
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
            const Text(
              'Кнопка «Подати заявку» відкриває форму: локація, час (Київ), '
              'назва, опис, відповідальний, за потреби телефон і примітки, '
              'напрямки діяльності. Звичайна заявка чекає рішення адміністрації. '
              'Організатор із дозволом самостійної публікації може одразу '
              'опублікувати подію, якщо час вільний.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Щотижневі серії створює адміністрація (або довірений організатор) '
              'як набір окремих подій до обраної дати. Окреме повторення можна '
              'перенести, скасувати або видалити без зміни всієї серії.',
            ),
            const SizedBox(height: 8),
            const AppLink(
              to: '/bookings/new',
              child: Text('Подати заявку'),
            ),
          ]),
          section('Напрямки в розкладі', [
            const Text(
              'Фільтр «Події за напрямками» є лише на сторінці Розклад. '
              'Можна обрати кілька міток; показуються події, що мають хоча б одну з них.',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/schedule', child: Text('Відкрити розклад')),
          ]),
          section('Контакти й зворотний зв’язок', [
            const Text(
              'Контакти простору — на окремій сторінці. '
              'Зауваження та пропозиції щодо сайту можна надіслати з меню '
              '(потрібен вхід організатора або адміністратора).',
            ),
            const SizedBox(height: 8),
            const AppLink(to: '/contacts', child: Text('Контакти')),
            const AppLink(
              to: '/feedback',
              child: Text('Зауваження та пропозиції'),
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
