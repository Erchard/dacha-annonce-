# Історичний звіт Stage 2 — до спрощення плану 2026-09-28

Цей звіт описує попередню спробу (9/16 Rules tests). Актуальний стан: [stage-status.md](stage-status.md); остання перевірка — 13/16, validBooking не переносилась. Актуальний порядок робіт — SPEC.md v1.1 §14.

## Результат

Stage 1 завершено після успішного FlutterFire browser smoke з локальними Auth/Firestore. Stage 2 виконано частково й позначено blocked: поточний anti-conflict Rules proof перевищує 1000 expressions. Перехід до Stage 3 не виконано. Deployment, commit і push не виконувалися.

Збережено мінімальний готовий результат: domain/DTO rooms/profiles/public events, Auth/read repository contracts, явні domain errors, ін’єктований Clock, UTC intervals/slots, Kyiv DST conversion та тести. Production booking engine, повні adapters/fakes і решта Stage 2 не заявляються готовими.

## Перевірки

- dart format lib test; фінальний format check — PASS, 25 файлів, 0 змін.
- flutter analyze — PASS, No issues found.
- flutter test — PASS, 16 tests.
- npm ci у rules-tests — PASS, 87 packages, без self-dependency.
- Emulator guard без environment — очікувана відмова до Firebase calls.
- Кореневий deny-all baseline у свіжому Emulator — PASS: усі 48 anonymous/authenticated Firestore operations відхилено.
- Rules candidate — 9 PASS / 7 FAIL із 16; помилка expression budget. Не є пройденим anti-conflict proof.
- FlutterFire browser smoke Stage 1 — PASS: Auth sign-in, denied Firestore read/write, home/404/back/mobile.

Детальне відтворення й budget: [stage2-gate.md](stage2-gate.md). Candidate Rules ізольовані від firebase.json; кореневі firestore.rules deny-all. Негативні Rules tests не компенсують провал позитивних сценаріїв.

## Точний список змінених або доданих source/documentation файлів

Тимчасові build/cache/log/.tools файли не включено. Раніше створені файли застосунку все ще untracked у Git, тому git diff не відображає цей список.

- README.md
- analysis_options.yaml
- firestore.rules
- docs/stage-status.md
- docs/data-model.md
- docs/security.md
- docs/stage2-gate.md
- docs/stage2-report.md
- docs/decisions/002-rules-validation-proposal.md
- lib/core/data/firestore_fields.dart
- lib/core/domain/page.dart
- lib/core/errors/domain_exception.dart
- lib/core/time/booking_time.dart
- lib/core/time/time_zone_service.dart
- lib/features/auth/domain/auth_repository.dart
- lib/features/auth/domain/user_profile.dart
- lib/features/auth/data/user_profile_dto.dart
- lib/features/rooms/domain/room.dart
- lib/features/rooms/domain/room_repository.dart
- lib/features/rooms/data/room_dto.dart
- lib/features/calendar/domain/public_event.dart
- lib/features/calendar/domain/public_event_repository.dart
- lib/features/calendar/data/public_event_dto.dart
- test/booking_time_test.dart
- test/dto_test.dart
- rules-tests/package.json
- rules-tests/package-lock.json
- rules-tests/environment.mjs
- rules-tests/fixtures.mjs
- rules-tests/booking-client.mjs
- rules-tests/measure.mjs
- rules-tests/firestore.stage2.rules
- rules-tests/test/booking.test.mjs
- rules-tests/test/audit.test.mjs

## Що блокує продовження

Описаний у decisions/002-rules-validation-proposal.md перенос повної schema validation із booking rule у обов’язковий history write не застосований. Автоматична перевірка дозволів відхилила його двічі через ризик послаблення захисту. Варіант зі збереженням validBooking у booking create/update був дозволений, але emulator gate також не пройшов. Загальний дозвіл самостійно приймати рішення автоматичний reviewer не прийняв як конкретне схвалення перенесення валідації.

Для продовження саме цього експерименту потрібен конкретний дозвіл перевірити перенесення validBooking у history rule у локальному Emulator. Тести повинні довести, що schema validation неможливо обійти через missing/replayed/forged history, та пройти worst-case move і конкурентні approvals. Без цього не активувати candidate Rules.

