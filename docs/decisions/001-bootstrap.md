# ADR 001: локальний bootstrap

Пункти про ручні production defines замінено погодженим [ADR 001a](001a-flutterfire-config.md). Інші рішення зберігаються.

Дата: 2026-09-28. Scope: лише Stage 1.

- Flutter Web, Material 3, українська локалізація, Riverpod та go_router. Версії обирає pub solver установленого stable SDK; результат фіксується в pubspec.lock.
- USE_FIREBASE_EMULATORS має бути явно true для локального запуску. Лише demo-dacha, loopback host, стандартні порти. Без config запуск показує помилку до ініціалізації Firebase. Автоматичного fallback немає.
- Production options передаються як публічні compile-time defines; це не secret storage. Реальні ID/region поки не визначені. Приклад конфігурації має порожні значення й не є готовим production config.
- Auth у production використовує LOCAL persistence (токен між відкриттями вкладки); емулятор лишається на SESSION через обмеження FlutterFire. Firestore persistent disk cache вимкнений.
- Firestore Rules deny-all; майбутні колекції відкриваються лише разом із негативними тестами відповідного Stage.
- Hosting має SPA rewrite для path URL та no-cache baseline. Оптимізація caching належить Stage 11.
- Початковий docs/SPEC.md збережено, точну копію додано в корінь як SPEC.md відповідно до його інструкції. Подальше джерело вимог — кореневий SPEC.md.

Документація сумісності: [Flutter stable](https://docs.flutter.dev/install/archive), [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup), [Emulator setup](https://firebase.google.com/docs/emulator-suite/install_and_configure), [Riverpod](https://pub.dev/packages/flutter_riverpod), [go_router](https://pub.dev/packages/go_router), [timezone](https://pub.dev/packages/timezone). Остаточний доказ сумісності — pub get, analyze, tests і release build, а не лише опис пакетів.

## Windows browser test runner

На цій версії Flutter `flutter test --platform chrome` зависав до виконання тесту: `_canvasKitHandler` перетворює URL на Windows path, але перевіряє prefix `canvaskit/`, тож повертає 404 для CanvasKit. Це підтверджено мережевими помилками окремого тестового Chrome та читанням SDK source. SDK не змінювався. Замість залежності від цього runner використовується окрема release web smoke entrypoint `test/firebase_bootstrap_smoke.dart` та Playwright із встановленим Chrome. Вона використовує справжній Firebase bootstrap і відмовляється працювати без явного emulator flag. Exact commands — README. Це локальна bootstrap-перевірка, не розширення scope до Stage 10.

