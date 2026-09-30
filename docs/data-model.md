# Дані та атомарні операції

Авторитетна схема: SPEC.md §§5–7; фактичні Rules — один кореневий firestore.rules. Вони використовуються і тестами, і firebase.json. Прикладні production-дані цього оновлення не створювались.

- users: приватний профіль, роль organizer/admin/developer, isDisabled. Самореєстрація створює лише organizer; клієнт не може призначати роль. Admin може змінювати isDisabled організатора разом з adminAudit.
- rooms: публічне читання тільки active; admin бачить всі. revision/lastAuditId пов’язують кожну зміну з незмінним adminAudit. Архівування не видаляє опубліковані події.
- bookings: приватні заявки; owner або admin. `responsibleName` — публічне ім’я відповідального. version і очікувана версія запобігають перезапису чужого рішення. history/{version} обов’язкова й незмінна. Щотижневий повтор — кілька звичайних заявок, без окремої колекції серій.
- publicEvents: лише точна публічна проєкція approved booking, включно з `responsibleName`; UID, контакти, причини відхилення/скасування не копіюються.
- rooms/{roomId}/occupancy/{blockId}: UTC блок 6 годин, 12 півгодинних слотів. ID — Unix seconds початку блока. lastMutationBookingId, lastMutationVersion, updatedAt/By підтверджують ту саму транзакцію. Повна перевірка вільності/власності й незмінності сторонніх слотів — у Rules; [обґрунтування](decisions/003-occupancy-version-witness.md).
- supportTickets: версіоновані звернення; тільки admin/developer. comments append-only, history/{version} append-only. Статус, priority, коментар та history змінюються атомарно. Підтримка не надає developer прав бронювання/керування користувачами.

BookingService спершу читає всі потрібні documents, потім записує booking/history, до чотирьох occupancy блоків і publicEvents. Pending не створює locks. Cancellation видаляє публічну проєкцію і звільняє тільки власні slots. Якщо транзакція відхилена, часткових змін немає.

SupportRepository має один transactional write path. Reopen потребує нового коментаря; конкурентна дія зі старою версією завершується staleVersion. Введений текст у формі зберігається для повтору після оновлення.

DTO перевіряють schemaVersion та типи. Час зберігається UTC; Flutter показує Europe/Kyiv. Firestore зберігає microsecond precision, тому серверний тест дрібного відхилення використовує 1000 ns, а не 1 ns, який Firestore округлює: https://firebase.google.com/docs/firestore/manage-data/data-types.

Пагінація: limit 25, максимум 100; сортування з documentId як стабільним tie-breaker. Calendar читає bounded range зі startAt lookback 6h і відсікає події, що вже завершилися до початку вікна. Усі composite indexes для реалізованих запитів — у firestore.indexes.json. No persistence у Firestore Web; приватні екрани демонтуються при logout/втраті дозволів.

Firebase Console та Admin SDK обходять Rules: власник має окремо дотримуватись зв’язності даних. Клієнтські Rules не захищають від помилкового адміністративного імпорту.
