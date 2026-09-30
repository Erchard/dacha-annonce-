# Stage 2: пропозиція розподілу перевірок Rules

Статус: не застосовано; відкладено. Поточний план — оптимізація зі збереженням validBooking у booking Rules. Поточний emulator proof не проходить ліміт 1000 expressions. Публічний сайт і deployed Rules не змінювались.

## Конкретна зміна

Зберегти одну атомарну транзакцію booking + occupancy + publicEvents + history.

1. Booking rule перевіряє actor, дозволений перехід, version + 1, усі old/new slots та обов’язкову наявність history саме нової version.
2. History rule перевіряє повну schema нового booking через getAfter, точну відповідність усіх history fields booking before/after, canonical version ID та реальне збільшення version.
3. Booking rule для approved вимагає publicEvents.bookingVersion == нова booking.version; для інших статусів — відсутність publicEvents.
4. PublicEvents rule перевіряє точний allowlist/projection, server timestamps і реальний перехід booking version. Незалежний запис mirror без booking mutation заборонений.
5. Occupancy checks залишаються взаємними: booking перевіряє всі потрібні slots після операції; occupancy перевіряє старий/новий booking, відсутність перезапису чужих slots і збереження сторонніх slots.

## Чому перевірка schema не може бути пропущена

History append-only. Неможливо завчасно створити history майбутньої version: його правило вимагає getAfter booking саме цієї version і збільшення поточної version. Тому збільшення booking.version вимагає нового history write, і правило цього write обов’язково виконує validBooking. Усі документи комітяться або відхиляються разом. Це спирається на інваріант, що початкові дані створені валідними транзакціями; Admin SDK є довіреною межею в обох реалізаціях.

## Обов’язкові перевірки до прийняття

- Позитивні create/approve/reschedule з двома old та двома new blocks, cancel.
- Simultaneous competing approvals: успішна рівно одна.
- Зайві/відсутні fields, неправильні типи, owner/actor forgery, timestamp nanos, invalid durations.
- Відсутній або заздалегідь підготовлений history, повтор version, незалежне оновлення mirror.
- Missing locks, stealing slots, partial release, unrelated-slot mutation.
- Emulator limits 10 calls/write, 20 calls/transaction, 1000 expressions; без послаблення валідації або розбиття атомарної транзакції.

Жоден успіх лише негативних тестів не є доказом: потрібні всі позитивні сценарії. Якщо gate не проходить, Stage 2 залишається незавершеним.
