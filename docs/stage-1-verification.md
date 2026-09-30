# Перевірки Stage 1

Дата: 2026-09-28. Середовище: Windows 10, Flutter 3.47.5 / Dart 3.13.4, Node 22.19.0, npm 10.9.3, Firebase CLI 15.31.0, Java 25.0.3, Chrome 153.0.8010.53. Playwright 1.63.0.

Команди Flutter/Dart виконувалися через `.tools/flutter/bin/*.bat` (або після додавання цієї папки в PATH поточної сесії).

| Команда | Результат |
|---|---|
| `flutter --version` | 3.47.5 stable, Dart 3.13.4 |
| `flutter doctor -v` | Web/Chrome готові; попередження про відсутність Flutter у глобальному PATH та Android SDK, який не потрібен web-only scope |
| `node --version`, `npm.cmd --version`, `java -version` | Версії наведено вище |
| `npx.cmd --no-install firebase --version` | 15.31.0 |
| `flutter create --platforms=web --project-name dacha_annonce .` | Створено web-only застосунок |
| `npm.cmd install --no-audit --no-fund` | CLI встановлений, package-lock.json створений |
| `npm.cmd install --save-dev --save-exact --no-audit --no-fund playwright` | Browser runner зафіксовано в lockfile |
| `flutter pub get` | Базові пакети сумісні, pubspec.lock створений |
| `dart format lib test` | Код відформатовано |
| `dart format --output=none --set-exit-if-changed lib test` | 8 файлів, 0 змін |
| `flutter test` | 8 unit/widget tests passed, включно 320 px / 200% text |
| `npx.cmd --no-install firebase emulators:exec --only auth,firestore --project demo-dacha "node scripts/emulator-smoke.mjs"` | Auth доступний; 48 anonymous/authenticated Firestore операцій denied; тимчасову identity видалено |
| `flutter build web --release --dart-define=USE_FIREBASE_EMULATORS=true` | Успішно; остаточна збірка містить обидва потрібні icon fonts |
| `flutter build web --release --target=test/firebase_bootstrap_smoke.dart --output=.tools/firebase-smoke --dart-define=USE_FIREBASE_EMULATORS=true` | Успішно; окрема непублічна browser probe |
| `node --check scripts/browser-smoke.mjs`, `node --check scripts/emulator-smoke.mjs` | Успішно |
| `Get-FileHash docs/SPEC.md,SPEC.md` | SHA256 збігається; вихідне ТЗ не змінене |
| `git diff --check` | Без помилок; нові файли залишені untracked, commit не виконувався |

Secret-pattern scan через `rg -l` поточних текстових файлів (виключено `.git`, `.tools`, `node_modules`, `.dart_tool`, build/logs) не знайшов private key blocks, private_key/refresh_token JSON або реальних Firebase key patterns. Це базова перевірка Stage 1, не повний security audit Stage 9.

## Виявлені проблеми та виправлення

- Windows sandbox helper не створює процес через `apply deny-read ACLs`: використано дозволені elevated PowerShell-команди. Прямий apply_patch та node_repl не спрацювали з тієї ж інфраструктурної причини.
- Офіційний URL JSON архіву Flutter повернув NoSuchKey; stable SDK отримано з офіційного GitHub flutter/flutter. Це лише локальна `.tools` інсталяція, не частина репозиторію.
- Перший build попереджав про CupertinoIcons; залежність додано, остаточний build без цього попередження.
- Analyze виявив зайвий import у початковому browser test; виправлено.
- `flutter test --platform chrome test/firebase_bootstrap_browser.dart` не виконав тест через 404 CanvasKit у Windows test server; запуск зупинено. Непрацездатний target замінено release smoke entrypoint, причина та альтернативний harness — ADR 001.
- Інтерактивний browser tool двічі завершився `trusted Node process exited unexpectedly`. Для перевірки власної web-збірки використано Playwright і встановлений Chrome.

## Межі перевірки

Реальний Firebase project не надано: production options, region, Spark/no-billing стан конкретного проєкту та реальна доставка Auth email не перевірялися. FlutterFire configure, deploy, production writes, commit/push не виконувалися. Firebase Rules harness та бізнес-сценарії належать наступним Stage. Повний screen reader/keyboard аудит не входить у цей bootstrap; ручний checklist наведений у README.
