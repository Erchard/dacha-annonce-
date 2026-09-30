# «Дача»

Flutter Web + Firebase Auth + Firestore. Публічний календар, заявки організаторів, модерація, кімнати, блокування акаунтів і техпідтримка. Інтерфейс українською, час — Europe/Kyiv.

Фактичні перевірки й незавершені пункти: [стан реалізації](docs/stage-status.md). Тестову версію для MI опубліковано 2026-09-29: https://dacha-annonce.web.app. Правила й індекси також опубліковані; актуальна перевірка готовності — у стані реалізації. Автоматичні листи з техпідтримки не підключені: [причина](docs/email.md).

## Запуск на Windows

Перевірене середовище: Flutter 3.47.5 / Dart 3.13.4, Node 22.19.0 / npm 10.9.3, Firebase CLI 15.31.0, Java 25, Chrome. Flutter та Java мають бути в PATH.

```powershell
flutter pub get
npm.cmd ci
npm.cmd --prefix rules-tests ci
```

У першому терміналі:

```powershell
npx.cmd --no-install firebase emulators:start --only auth,firestore --project demo-dacha
```

У другому терміналі підготувати локальні приклади. **Seed видаляє всі попередні Auth/Firestore дані тільки demo-dacha в локальних емуляторах.** Скрипт відмовляється працювати з іншими project/hosts.

```powershell
$env:GCLOUD_PROJECT='demo-dacha'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
npm.cmd --prefix rules-tests run seed
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Локальні акаунти: `admin@example.test`, `organizer@example.test`, `developer@example.test`, `disabled@example.test`. Пароль кожного: `LocalDemo123!`. Вони існують тільки в Emulator; не створювати їх у production. Emulator UI: http://127.0.0.1:4000.

Без emulator flag `flutter run -d chrome` використовує `DefaultFirebaseOptions.currentPlatform` для **dacha-annonce**. Якщо емулятори недоступні, застосунок не перемикається на production. Клієнтський Firebase config у `lib/firebase_options.dart` публічний; приватні ключі не потрібні й у браузер не додаються.

## Як користуватись

- Відвідувач: календар, фільтр кімнати й місяця, деталі події, список активних кімнат.
- Організатор: реєстрація → лист підтвердження → «Я підтвердив адресу» → «Подати заявку». Власні pending можна редагувати; схвалену подію — скасувати до початку.
- Адміністрація: меню «Адміністрування» → pending → схвалити/відхилити. Можна створити подію одразу, перенести її, змінити текст, скасувати; створити/редагувати/архівувати кімнату; заблокувати організатора.
- Підтримка: адміністрація створює звернення; розробник приймає, опрацьовує, завершує, змінює пріоритет. Повторне відкриття потребує коментаря. Коментарі та історія незмінні.

Pending не займає час. Схвалення атомарно резервує кімнату. Крок 30 хвилин, тривалість до 6 годин, новий початок не далі 180 днів. Перетин заборонений серверними Rules. На межі літнього часу форма пояснює неіснуючий час або пропонує вибрати один із двох можливих моментів. Title/description схваленої події публічні.

Списки мають обмежені сторінки й кнопку «Завантажити ще». Лічильники показують лише завантажені записи. Оновлення календаря та робочих списків — кнопкою «Оновити». Повідомлення про мережеву помилку не означає успішне збереження; після невизначеної відповіді перевірте запис перед повтором. Форма зберігає той самий ID, тому повтор не створює копії.

## Перевірки

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npx.cmd --no-install firebase emulators:exec --only auth,firestore --project demo-dacha "npm.cmd --prefix rules-tests test"
```

Наскрізна перевірка реального release Flutter у Chrome; потрібні вільні порти 8080/9099, встановлений Chrome. Вона сама запускає seed у demo-проєкті:

```powershell
flutter build web --release --target=test/booking_engine_smoke.dart --output=.tools/booking-smoke --dart-define=USE_FIREBASE_EMULATORS=true
flutter build web --release --dart-define=USE_FIREBASE_EMULATORS=true
npx.cmd --no-install firebase emulators:exec --only auth,firestore --project demo-dacha "node scripts/browser-smoke.mjs"
```

Скриншоти/діагностика залишаються в ігнорованій `.tools/qa/`. `--probe-only` перевіряє лише Flutter-транзакції. Тести Rules використовують кореневий `firestore.rules`, той самий файл, що deployment. Emulator не перевіряє готовність production composite indexes; вони описані в `firestore.indexes.json` і потребують окремого очікування після deployment.

Production build (без emulator flag), публікація лише за окремим дозволом:

```powershell
flutter build web --release
```

## Дані та експлуатація

[ТЗ і план](SPEC.md) · [схема й гарантії](docs/data-model.md) · [публікація](docs/deployment.md) · [ролі, квоти та відновлення](docs/operations.md).

Єдиний шлях запису бронювання — `BookingService`; підтримки — `SupportRepository`. Публічні `publicEvents` не містять UID або приватних причин. Активна роль перевіряється Rules за профілем, а не лише меню. Призначення першого admin/developer виконує власник Firebase через Console після створення відповідного профілю. Клієнт не має можливості призначати ролі. Блокування в застосунку не видаляє Auth identity.

Немає автоматичного видалення bookings/support, платних сервісів, Cloud Functions чи email relay. `.env`, service account keys, build, node_modules та локальна діагностика не входять у Git. Вміст `docs/SPEC.md` і старі stage reports зберігається як історія; актуальні вимоги — кореневий `SPEC.md`.
