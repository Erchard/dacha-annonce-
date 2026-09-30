# Перевірка транзакцій бронювання

Gate пройдено 2026-09-29. Актуальний набір Rules: 25/25; попередні звіти 13/16 та 9/16 — історія, не поточний стан.

Перевірено approved create на два 6h blocks, перенесення між кімнатами на чотири distinct blocks, cancel, adjacent events, відмову при зайнятому часі, паралельні операції та збереження пов’язаних documents. Негативні тести перевіряють відсутність history/public/locks, forged actor/version/witness, часткове звільнення, сторонні slots, приватність і ролі.

Повна validBooking залишається у booking create/update. Кожен потрібний occupancy block підтверджує нові bookingId/version/request.time і проходить незалежну повну перевірку ownership/free slots. ADR 003 пояснює взаємний зв’язок. Пропозицію перенести validBooking у history (ADR 002) не застосовано.

Найбільша операція має booking + history + public + 4 occupancy writes. Booking forward-check читає role, room, history/public і чотири blocks; reciprocal checks читають before/after booking та role. Реальні позитивні worst-case сценарії пройшли в Emulator без перевищення document/expression budgets; теоретична необмежена кешованість не використовується як доказ. Подальші зміни Rules потребують повторення цих сценаріїв.

Dart BookingService додатково перевірений як справжній release Flutter-клієнт у Chrome: усі транзакції виконуються через FlutterFire. Виявлене обгортання DomainException на Dart/JS межі обробляється у firestoreTransaction: початковий typed rejection зберігається, транзакція нормально abort-иться. Текст помилки не парситься, відмова не перетворюється на успіх.

Єдиний файл правил — кореневий firestore.rules. Harness вимагає demo-dacha/127.0.0.1; production credential fallback відсутній. Admin bypass використовується лише для локальних fixtures.
