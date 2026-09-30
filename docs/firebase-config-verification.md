# Звіт: перехід bootstrap на FlutterFire options

Scope: точкове виправлення Stage 1 за командою користувача, без переходу до наступних Stage.

Звичайний запуск використовує `DefaultFirebaseOptions.currentPlatform` з наявного `lib/firebase_options.dart` для `dacha-annonce`. `AppEnvironment` більше не приймає вручну Firebase API key, app ID, project ID, sender ID чи auth domain. Для `USE_FIREBASE_EMULATORS=true` обираються окремі фіксовані demo options, а platform getter не викликається. Збережено loopback host validation, порядок підключення емуляторів, session persistence Auth та вимкнений disk cache Firestore.

Початкова умова з RegExp у файлі була синтаксично повною; підозра про відсутню дужку не підтвердилася. Стару ручну production-валідацію прибрано разом із дублюванням конфігурації.

## Точний список змінених файлів

- `lib/core/config/app_environment.dart` — вибір generated/demo options, видалення ручних production defines.
- `lib/core/config/firebase_bootstrap.dart` — визначення options до Firebase.initializeApp.
- `test/app_environment_test.dart` — 5 перевірок нового способу конфігурації та ізоляції emulator mode.
- `README.md` — команди звичайного й emulator запуску, build без ручного JSON config.
- `docs/decisions/001-bootstrap.md` — позначення замінених рішень про production defines.
- `docs/decisions/001a-flutterfire-config.md` — новий запис погодженої зміни архітектури.
- `docs/operations.md` — відомий project ID, розмежування звичайного й emulator режимів.
- `docs/stage-status.md` — запис виправлення в межах Stage 1; Stage 2 не розпочинався.
- `docs/firebase-config-verification.md` — цей звіт.
- `config/production.example.json` — видалений застарілий шаблон.

Хеш `lib/firebase_options.dart` не змінився. Firebase Rules, firebase.json, .firebaserc, залежності/lockfiles, main/router і сторонні файли не змінювалися. Приватні ключі та секрети не додавалися. Оскільки попередня реалізація ще untracked, список отримано порівнянням хешів до/після цього виправлення, а не лише git diff.

## Перевірки

Використано встановлений користувачем SDK з PATH: D:/dev/flutter/bin, Flutter 3.47.5 stable / Dart 3.13.4.

- `dart format lib test` — 9 Dart файлів, відформатовано 3 змінені файли.
- `dart format --output=none --set-exit-if-changed lib test` — успішно, 0 змін.
- `flutter analyze` — No issues found.
- `flutter test` — усі 9 тестів пройшли.
- `flutter test --dart-define=USE_FIREBASE_EMULATORS=true test/app_environment_test.dart` — усі 5 конфігураційних тестів пройшли також із явно ввімкненим прапорцем.
- `git diff --check` — без помилок; нові файли не додавалися до staging.

Unit tests виконуються у VM, де згенерованої native Firebase конфігурації немає: звичайний getter очікувано відхиляє unsupported platform, тоді як emulator options працюють незалежно від платформи. Фактичну ініціалізацію реального Firebase цим не підтверджено.

## Наступна ручна перевірка

За домовленістю користувач окремо запустить `flutter run -d chrome` і перевірить реальну ініціалізацію `dacha-annonce`. Для emulator mode: `npm.cmd run emulators` та в іншому терміналі `flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true`. Необхідність перевірки реальних Console settings/region/billing залишається. Commit, push, deploy та записи у production не виконувалися. Повний Stage 1 лишається in_progress до завершення його окремого acceptance checklist.

Додаткова перевірка: `flutter build web --release` без жодних Firebase defines — успішно (Built build/web). Це перевіряє компіляцію Web гілки зі стандартним FlutterFire config; запуск реального Firebase у браузері не виконувався. Окремий `scripts/browser-smoke.mjs` у цьому точковому виправленні не запускався; інтерактивна browser-перевірка залишається наступним кроком користувача.

`npx.cmd --no-install firebase emulators:exec --only auth,firestore --project demo-dacha "node scripts/emulator-smoke.mjs"` — успішно: Auth Emulator доступний, 48 anonymous/authenticated Firestore операцій denied, тимчасовий тестовий користувач видалений, емулятори завершили роботу. Виправлення конфігурації завершено; повний Stage 1 лишається in_progress до окремої browser/acceptance перевірки.
