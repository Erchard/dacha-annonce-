# ADR 001a: стандартна FlutterFire конфігурація

Статус: прийнято за прямою командою користувача; виправлення в межах Stage 1.

Замінює пункти ADR 001 щодо ручних production defines та помилки запуску без них. Користувач виконав `flutterfire configure --project=dacha-annonce`; згенерований `lib/firebase_options.dart` уже містить Web configuration цього проєкту.

- Звичайний запуск і release build використовують `DefaultFirebaseOptions.currentPlatform` без дублювання Firebase полів у `AppEnvironment`.
- `USE_FIREBASE_EMULATORS=true` обирає фіксовані options `demo-dacha` до звернення до platform config. Emulator mode не потребує production credentials чи підтримки поточної платформи у згенерованому getter.
- `FIREBASE_EMULATOR_HOST` лишається опційним loopback host. Auth/Firestore підключаються до емуляторів до операцій; production fallback відсутній.
- FlutterFire файл збережено без змін. Web client identifiers не є приватними ключами; серверні секрети не додаються.
- Застарілий config/production.example.json видалено. Наявний ігнор для локального config/production.json зберігається, щоб не відкрити випадково старі локальні файли.
- Firestore Rules, CLI aliases, persistence policy, routing та решта Stage scope не змінюються.

Це погоджена зміна початкового припущення SPEC про запуск без real config: реальна конфігурація тепер уже існує, а звичайний запуск свідомо використовує її. Ручна реальна ініціалізація та перевірка Console settings залишаються наступним кроком. Результати автоматичних перевірок — docs/firebase-config-verification.md.
