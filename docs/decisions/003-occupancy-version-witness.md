# ADR 003: version witness для occupancy

Статус: прийнято 2026-09-29 після позитивних/негативних Rules tests і реального Flutter transaction smoke.

Повна validBooking залишається у booking create/update. Перевірка всіх old/new slots, заборона крадіжки та збереження сторонніх слотів залишаються у occupancyWrite. Змінюється тільки доказ того, що кожен із максимум чотирьох блоків обов’язково пройшов цю перевірку у поточній атомарній операції.

До occupancy schema додається lastMutationVersion:int. Booking forward-check вимагає getAfter(block).lastMutationBookingId == bookingId, lastMutationVersion == нова booking.version, updatedAt == request.time. Occupancy reverse-check вимагає lastMutationVersion == getAfter(booking).version та реальне збільшення booking version; після цього перевіряє точні old/new slots, вільність нових slots і незмінність сторонніх.

Попередній block не може бути свідком майбутньої version: запис його metadata без відповідної зміни booking заборонено. Orphan booking/history/locks створити не можна; booking і version history не видаляються, version збільшується. Отже stale witness не дає пройти booking write. Кожен потрібний блок мусить бути записаний у тій самій транзакції та пройти повний occupancyWrite. Для двох booking одним block write witness може відповідати лише одному, тому batch обходу немає.

Це розширення metadata schema v1 до першого production використання. Не потрібні міграція production, сервер, новий сервіс, секрети чи fallback. Немає перенесення або вилучення validBooking. Не переносити candidate у deployment config до позитивних create/approve/reschedule/cancel, race та malicious-write tests, включно з forged/stale witness.

