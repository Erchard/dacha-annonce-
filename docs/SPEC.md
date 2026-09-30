# «Дача» — технічне завдання та покрокова дорожня карта MVP

Версія: 1.0 • Дата: 2026-09-28 • Мова продукту: українська

Цільовий репозиторій: `D:\Projects\dacha-annonce-`.
Цей документ потрібно покласти в корінь репозиторію як `SPEC.md`. Сам документ не є командою реалізувати всі етапи. Поточне завдання — підготувати специфікацію; реалізація починається лише за окремою командою користувача.

## 1. Мета та межі MVP

«Дача» — адаптивний вебзастосунок для публічного календаря заходів і бронювання кімнат/локацій. Відвідувач бачить схвалені події; організатор подає заявку; адміністрація MI приймає рішення та керує розкладом. MI може повідомляти розробника про помилки й побажання через вбудовану техпідтримку.

Стек: Flutter Web, Firebase Authentication, Cloud Firestore Standard edition, Firebase Hosting. На старті немає Render, власного API-сервера, Cloud Run, Cloud Functions або платних Firebase Extensions. Ціль — $0 регулярних витрат за малого навантаження в межах актуальних безкоштовних квот, без автоматичного переходу на платний тариф. Безкоштовний тариф не означає необмежені ресурси чи гарантовану доступність після вичерпання квот.

До MVP входять:

- Публічний календар approved-подій, деталі, список кімнат, фільтр кімнати, мобільний режим списку.
- Email/password registration, login, logout, password reset, підтвердження email.
- Власні заявки організатора, редагування pending, скасування власної заявки/бронювання.
- Модерація, створення й редагування подій MI, керування кімнатами, базові лічильники.
- Support tickets, коментарі та незмінювана клієнтами історія змін.
- Email developer про новий ticket та новий коментар MI після перевірки здійсненності на Stage 8.
- Security Rules, індекси, автоматичні перевірки критичних сценаріїв і документація запуску.

Не входять: recurring events, multi-room events, оплата, квитки, облік відвідувачів, чат, SMS, push, native mobile apps, складна аналітика, rich text/HTML, вкладення, імпорт календарів, синхронізація з Google Calendar, багатомовність, автоматична реєстрація домену.

### 1.1 Початкові продуктові рішення

1. Реєстрація організатора відкрита; окремого погодження облікового запису немає. Для подання заявки email має бути підтверджений.
2. Одна заявка — одна кімната. Кімната може представляти зал або іншу незалежно броньовану локацію.
3. `pending` — прохання про бронювання, яке ще не резервує час. Кілька pending можуть перетинатися. Під час подання UI попереджає про approved-конфлікт; остаточна гарантія застосовується під час схвалення.
4. Лише `approved` займає кімнату. `rejected` і `cancelled` не займають час і не публікуються.
5. MI створює одразу approved-подію, але проходить ту саму перевірку конфліктів.
6. Організатор не редагує approved-подію: скасовує й подає нову. MI може атомарно змінювати час/кімнату approved-події за відсутності конфлікту.
7. Щоб забезпечити перевірювану в Rules зайнятість без backend, MVP має крок часу **30 хвилин**, тривалість **30 хвилин–6 годин**, горизонт подання **180 діб**. Це свідомі змінювані продуктові обмеження, а не обмеження Firestore. Тривалі заходи — подальше розширення з новим доказом коректності Rules.
8. У користувацькому інтерфейсі всі дати й час — `Europe/Kyiv`, незалежно від часової зони пристрою.
9. Публічні title/description не повинні містити контакти або конфіденційні відомості. Форма чітко попереджає, що ці поля будуть оприлюднені після схвалення.
10. Після завершення подія залишається approved в архівному календарі. Автоматичне очищення зайнятості не потрібне: ключі містять дату.

## 2. Обов’язковий робочий протокол IDE Codex

Перед кожним Stage прочитати `AGENTS.md`, `SPEC.md`, `README.md`, поточний код, конфігурацію та `git status`. Якщо репозиторій уже містить застосунок, інтегрувати зміни; не запускати шаблонізацію поверх файлів без перевірки. Не змінювати сторонню незавершену роботу користувача.

**Виконувати рівно один Stage за один дозвіл користувача.** Після Definition of Done зупинитися. Фраза «почни Stage 1» дозволяє лише Stage 1. Не переходити до наступного етапу без явної команди, навіть якщо це зручно. Якщо користувач явно просить виправити поточний Stage — виправити його, не розширюючи scope.

Правила виконання:

- Спершу стисло описати scope обраного Stage та виявлені передумови.
- Працездатність наявного застосунку зберігати; робити невеликі узгоджені зміни.
- Не виконувати commit, push, merge, deployment або зміни production-даних без прямої команди на відповідну дію. Підготовка deployment дозволена Stage 11; публікація — тільки явно дозволена.
- Не додавати платні сервіси, підписки, trial із подальшим списанням, billing account чи Blaze. Якщо без цього неможливо виконати вимогу — пояснити конкретний блокер і варіанти, не маскувати незавершеність.
- Не додавати secrets у Git, Flutter assets, `--dart-define`, JavaScript bundle, журнали або скриншоти. Build-time змінні Flutter Web також доступні клієнту.
- Security Rules та їхні негативні тести створюються разом із кожною функцією. Stage 9 — посилення, а не перший захист.
- Не видавати mock/demo behavior за робочу Firebase-інтеграцію. Не застосовувати production fallback, якщо emulator недоступний.
- Не обходити невдалий тест послабленням захисту чи видаленням перевірки.
- Якщо потрібні console settings/credentials користувача, завершити доступну локальну частину й дати точний перелік ручних дій. Заблокований DoD не позначати виконаним.
- Версії пакетів вибрати за актуальною сумісністю під час Stage 1; зафіксувати lockfiles. Не використовувати `any` або платні календарні пакети.

Фінальний звіт кожного Stage обов’язково містить:

1. Stage, реалізовану поведінку та статус DoD.
2. Змінені/додані файли з коротким призначенням.
3. Фактично виконані команди та результати; окремо невиконані перевірки і причини.
4. Як перевірити вручну; які ручні дії ще потрібні користувачу.
5. Ризики, відкриті питання та зміни припущень.
6. Фразу: «Stage N завершено» або «Stage N заблоковано: …». Далі зупинка без автоматичного початку наступного Stage.

Стан вести в `docs/stage-status.md` (not_started / in_progress / blocked / done). Архітектурні зміни — у `docs/decisions/`. Не переписувати погоджений scope мовчки.

## 3. Архітектура Flutter

### 3.1 Пакети та залежності

Базово: `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_riverpod`, `go_router`, `intl`, `timezone`, Flutter localization SDK. State management — Riverpod без обов’язкової code generation: `Provider` для залежностей, `StreamProvider` для Auth/даних, `AsyncNotifier` або `Notifier` для команд і стану форм. Material 3.

Календар MVP можна реалізувати стандартними Flutter widgets: month grid на широкому екрані й agenda list на телефоні. Сторонній календарний пакет додавати лише за наявності реальної користі, сумісності та придатної безкоштовної ліцензії.

### 3.2 Структура

```text
lib/
  main.dart
  app/                  # bootstrap, router, theme, localization
  core/
    config/             # environment, public Firebase options
    errors/             # domain errors та українські повідомлення
    time/               # Clock, Kyiv conversion, interval/slot helpers
    widgets/            # loading/error/empty, responsive shell
  features/
    auth/{domain,data,application,presentation}/
    rooms/{domain,data,application,presentation}/
    calendar/{domain,data,application,presentation}/
    bookings/{domain,data,application,presentation}/
    admin/{application,presentation}/
    support/{domain,data,application,presentation}/
    notifications/{domain,data,application}/
test/                   # unit та widget tests
integration_test/       # emulator-backed user flows
rules-tests/            # Node tests для Firestore Rules
scripts/                # перевірки/seed лише emulator, documented admin utilities
docs/
  decisions/
  stage-status.md
  data-model.md
  security.md
  deployment.md
  operations.md
firebase.json
.firebaserc
firestore.rules
firestore.indexes.json
README.md
SPEC.md
```

Feature directories створювати за потреби, без десятків порожніх файлів. Domain не залежить від widgets або `DocumentSnapshot`; перетворення Firestore DTO ↔ domain виконуються в data layer. Timestamp мапиться в UTC `DateTime`; status — enum з контрольованою обробкою невідомого значення.

### 3.3 Контракти

- `AuthRepository`: session stream, register, signIn, signOut, sendVerification, resetPassword, reloadUser.
- `UserRepository`: watchMyProfile, updateMyDisplayName, admin listProfiles/setDisabled.
- `RoomRepository`: watchActiveRooms, getRoom, admin upsert/archive.
- `PublicEventRepository`: listRange, getPublishedEvent; лише публічна проєкція.
- `BookingRepository`: get, listMine, listForAdmin, createPending, updatePending, approve, reject, cancel, adminCreateApproved, adminReschedule.
- `SupportRepository`: list/get/createTicket, addComment, transitionStatus, watchHistory.
- `NotificationService`: інтерфейс стану інтеграції; browser implementation не має секретів і не вирішує, кому надсилати довільний лист.
- `BookingService`: orchestration бізнес-переходів і транзакцій; єдиний код для всіх змін зайнятості.
- `Clock` ін’єктується для тестів; `TimeZoneService` відповідає за Kyiv ↔ UTC.

UI не робить прямих Firestore writes. Репозиторії реалізуються Firebase-адаптерами та in-memory fakes для тестів. Не будувати generic CRUD framework або надмірний use-case layer для простих читань.

Domain errors: `unauthenticated`, `permissionDenied`, `emailNotVerified`, `accountDisabled`, `validation`, `bookingConflict`, `staleVersion`, `notFound`, `networkUnavailable`, `quotaExceeded`, `unexpected`. Зберігати технічну причину без приватного payload; показувати зрозуміле повідомлення й доступну дію.

## 4. Ролі та авторизація

Visitor не має user document. Джерело app-role — `users/{uid}.role`. Початковий profile користувач може створити лише для власного UID з `role=organizer`, `isDisabled=false`; Rules перевіряють усі поля. Клієнт не може змінити role. Email для входу зберігається в Firebase Auth, пароль ніколи не зберігається у Firestore.

| Дія | visitor | organizer | admin (MI) | developer |
|---|---|---|---|---|
| Active rooms та public approved events | так | так | так | так |
| Власний profile / displayName | ні | так | так | так |
| Створити pending | ні | verified, active | так | ні |
| Читати заявки | ні | тільки власні | усі | ні |
| Редагувати pending | ні | тільки власні | так | ні |
| Скасувати pending/approved | ні | власні, до початку | так | ні |
| Approve/reject/admin event edit | ні | ні | так | ні |
| Керувати кімнатами | ні | ні | так | ні |
| Перелік users / app disable organizer | ні | ні | так | ні |
| Призначати admin/developer | ні | ні | ні | ні |
| Support читання/коментарі | ні | ні | так | так |
| Створити ticket | ні | ні | так | ні |
| Змінити support status | ні | ні | обмежено | так |

Developer не отримує права MI автоматично. Перші admin/developer призначаються власником Firebase project через Console або окремий локальний Admin SDK utility з явно дозволеною операцією. Це не екран self-service. Admin SDK обходить Rules — доступ до нього обмежений IAM/власником, жодного service account key у браузері.

MI може поставити `isDisabled=true/false` лише organizer. Це application block, а не Firebase Auth account disable: Auth login може пройти, але Rules блокують приватні читання й записи. MI не може блокувати інших admin/developer, змінювати role або видаляти Auth accounts. Profile власник може прочитати для повідомлення про блокування.

Routing guards потрібні для UX, але авторизація кожної операції забезпечується Firestore Rules. Втрата ролі чи блокування має діяти на наступний запит, без довіри до закешованого UI.

## 5. Firestore: модель даних

Позначення: `string`, `int`, `bool`, `Timestamp`, `map`, `list`, `null`. Для кожної колекції Rules використовують allowlist полів та перевірки типів. Указані поля обов’язкові, якщо не зазначено `null`; довільні зайві поля заборонені. ID — випадковий Firestore ID, якщо не описано інше. Усі часи — UTC Timestamp, не рядки локального часу.

### 5.1 `users/{uid}` — приватний profile

| Поле | Тип | Вимога |
|---|---|---|
| displayName | string | 2–80 символів після trim |
| role | string | organizer / admin / developer |
| isDisabled | bool | false під час self-registration |
| createdAt, updatedAt | Timestamp | server timestamps |
| createdBy, updatedBy | string | UID актора; createdBy=uid при реєстрації |
| schemaVersion | int | 1 |

Email не дублювати за відсутності потреби. MI бачить UID/displayName/role/disabled; це достатній базовий огляд. Users collection не публічна. Документ відсутній після signup failure — користувач бачить відновлення profile, а не автоматичне розширення прав.

### 5.2 `rooms/{roomId}` — тільки публічно безпечні поля

`name:string(2..80)`, `description:string(0..1000)`, `locationLabel:string(0..160)`, `capacity:int|null(1..1000)`, `isActive:bool`, `sortOrder:int(0..10000)`, `createdAt:Timestamp`, `updatedAt:Timestamp`, `schemaVersion:int=1`.

Без контактів, ключів доступу та приватних приміток. UID акторів змін — у приватному audit, а не public room document. Visitor list/get дозволено лише active rooms. MI бачить усі. Room не видаляється, а архівується. Архівація не скасовує вже схвалені події; назва/місце зберігаються в event snapshot. Нові заявки й перенесення в inactive room заборонені.

### 5.3 `bookings/{bookingId}` — приватне джерело істини

| Поле | Тип | Вимога |
|---|---|---|
| organizerId | string | UID; незмінний після створення |
| roomId | string | існуюча кімната |
| title | string | 3–120 символів |
| description | string | 0–5000, plain text, призначено для публікації |
| startAt, endAt | Timestamp | UTC, start < end |
| timeZone | string | рівно Europe/Kyiv |
| status | string | pending / approved / rejected / cancelled |
| roomNameSnapshot, locationSnapshot | string | заповнює MI під час approval/admin edit |
| rejectionReason | string|null | 3–1000 для rejected, інакше null |
| cancellationReason | string|null | 0–1000 для cancelled, інакше null |
| reviewedAt, reviewedBy | Timestamp|null, string|null | лише модераційна дія |
| cancelledAt, cancelledBy | Timestamp|null, string|null | лише cancelled |
| occupancyBlockIds | list<string> | 1–2 у хронологічному порядку; детерміновано з часу |
| version | int | 1 при create, +1 при кожній зміні |
| lastAction | string | create / edit / approve / reject / cancel / reschedule |
| createdAt, updatedAt | Timestamp | server timestamps |
| createdBy, updatedBy | string | UID актора |
| schemaVersion | int | 1 |

Snapshot для pending може бути порожнім рядком. При publication він звіряється з room. Зміна назви room не переписує історичні snapshots. `occupancyBlockIds` обчислюються навіть для pending, але lock documents для pending не створюються. Жодних attachments, довільних participant lists або private contact fields у MVP.

### 5.4 `publicEvents/{bookingId}` — публічна проєкція

Існує лише поки booking.status=approved. Поля: `title`, `description`, `roomId`, `roomNameSnapshot`, `locationSnapshot`, `startAt`, `endAt`, `timeZone`, `bookingVersion:int`, `publishedAt:Timestamp`, `updatedAt:Timestamp`, `schemaVersion:int`.

Немає organizerId, email, reviewedBy, rejectionReason чи UID audit-акторів. Використовувати окремий DTO, не серіалізувати booking повністю. Кожне approve/admin edit/cancel атомарно синхронізує проєкцію. При cancel public document видаляється, приватний booking залишається. Rules перевіряють точну відповідність полів booking через `getAfter`; booking Rules перевіряють наявність актуальної проєкції або її відсутність після операції. Наявність approved booking сама по собі не дозволяє опублікувати довільний текст.

### 5.5 `rooms/{roomId}/occupancy/{blockId}` — приватна зайнятість

Ця колекція — механізм взаємовиключення, не публічний календар.

- UTC block = рівно 6 годин; slot = рівно 30 хвилин; 12 slots на block.
- `blockId` — canonical decimal string від UTC Unix seconds початку блока, кратного 21600. Приклад обчислює єдиний helper, а Rules перевіряють відповідність ID/часу; не довіряти довільному ID з клієнта.
- `blockStartAt:Timestamp` — точний початок UTC блока.
- `slots:map<string,string>` — рівно ключі `s00`…`s11`; значення `''` (вільно) або bookingId.
- `lastMutationBookingId:string` — єдиний booking, чиї slots змінюються цією операцією.
- `updatedAt:Timestamp`, `updatedBy:string`, `schemaVersion:int=1`.

Документ при першій потребі створюється атомарно з booking. Порожній існуючий документ не видаляється у MVP. Клієнтські delete заборонені. Читає admin; organizer може виконувати одиничні get для власної approved-події на скасування, але не list чужої зайнятості. Перевірка такого get звіряє явно збережений у власному booking room/block, а API для читання може вимагати окремого дозволеного шляху/механізму; якщо query context не можна безпечно передати Rules, застосувати описане нижче правило читання.

Практичне правило для MVP: authenticated active organizer може `get` occupancy документа (там тільки непрозорі booking IDs), `list` — лише admin. Це розкриває наявність зайнятих slots, яка і так публічна для approved events, але не персональні дані. Відсутні allowlist/personal-data guarantees — не розширювати get. Цю прозорість зафіксувати в `docs/security.md`.

### 5.6 `bookings/{id}/history/{version}`

ID = canonical decimal string booking version. Поля: `version:int`, `action:string`, `actorId:string`, `actorRole:string`, `at:Timestamp`, `fromStatus:string|null`, `toStatus:string`, `oldRoomId:string|null`, `newRoomId:string`, `oldStartAt:Timestamp|null`, `oldEndAt:Timestamp|null`, `newStartAt:Timestamp`, `newEndAt:Timestamp`.

Append-only, create атомарно з відповідною booking version. Значення звіряються зі станами booking до/після; update/delete заборонені. Читання — owner/admin. Це історія змін, не юридично незмінний журнал: project owner/Admin SDK технічно може її змінити.

### 5.7 `supportTickets/{ticketId}`

`type:string(bug|feature|feedback)`, `title:string(3..160)`, `body:string(10..10000)`, `status:string(new|accepted|in_progress|done|rejected|closed)`, `priority:string(low|normal|high)`, `createdBy:string`, `createdAt:Timestamp`, `updatedBy:string`, `updatedAt:Timestamp`, `lastActivityAt:Timestamp`, `version:int`, `lastAction:string`, `schemaVersion:int=1`.

MI створює ticket зі status=new, priority=normal або обраною оцінкою. Вміст після створення незмінний: уточнення — коментарями. Priority може змінювати developer із history. Attachments відсутні. Не вводити assignment для єдиного developer.

### 5.8 `supportTickets/{ticketId}/comments/{commentId}`

`body:string(1..5000)`, `authorId:string`, `authorRole:string(admin|developer)`, `createdAt:Timestamp`, `ticketVersion:int`, `schemaVersion:int=1`.

Append-only: редагування/видалення відсутні. Create атомарно оновлює ticket version/lastActivityAt/updatedAt і додає history. authorRole звіряється з users; не довіряти полю клієнта. Нові коментарі дозволені також у done/rejected/closed, але не змінюють status автоматично.

### 5.9 `supportTickets/{ticketId}/history/{version}`

`version:int`, `action:string(created|commented|status_changed|priority_changed)`, `actorId:string`, `actorRole:string`, `at:Timestamp`, `fromStatus:string|null`, `toStatus:string`, `commentId:string|null`, `fromPriority:string|null`, `toPriority:string`.

Create-only, детермінований version ID; одночасний update ticket + history + optional comment. History не містить дубльованого тексту коментарів. Для зв’язку ticket з history додати `lastHistoryId:string` і `lastCommentId:string|null` до ticket schema; значення version і comment pointer перевіряти в обидва боки Rules. Одночасні коментарі ретраяться транзакцією.

### 5.10 `adminAudit/{auditId}`

Append-only приватний audit змін room/user: `entityType:string(room|user)`, `entityId:string`, `action:string`, `actorId:string`, `at:Timestamp`, `changedFields:list<string>`. Читає admin; developer доступу не має. Для обов’язкового атомарного audit у відповідних приватних metadata документах зберігати revision/lastAuditId; якщо це збільшує scope, на Stage 2 явно визначити схему metadata. Мінімум MVP — незмінні createdAt і правильні updatedAt плюс перевірений audit для адміністративних змін; не обіцяти обов’язковий audit, якщо Rules не перевіряють його наявність.

### 5.11 Email integration metadata — тільки після Stage 8

До вибору способу dispatch не створювати робочу `mail` collection з довільним recipient. Можлива схема `notificationDeliveries/{sourceEventId}`: `sourcePath`, `status(pending|sent|failed)`, `attempts:int`, `nextAttemptAt:Timestamp|null`, `sentAt:Timestamp|null`, `providerMessageId:string|null`, `lastErrorCode:string|null`. Це trusted sender-only writes; admin/developer можуть читати лише безпечний delivery status. Destination email і секрети належать конфігурації sender, не клієнтському документу. Остаточна схема й permissions — ADR Stage 8.

## 6. Query contract та індекси

Кожна list query має `limit` (типово 25, максимум 100), стабільний порядок і cursor pagination. Не завантажувати всю базу для count чи фільтрації. Rules не є фільтром: organizer query обов’язково `organizerId == currentUid`; public rooms — `isActive == true`. Недостатньо відфільтрувати результат у Dart.

| Колекція | Query | Composite index |
|---|---|---|
| rooms | active, orderBy sortOrder | isActive ASC, sortOrder ASC |
| publicEvents | startAt у bounded range, orderBy startAt | single-field startAt |
| publicEvents | roomId + той самий range | roomId ASC, startAt ASC |
| bookings | owner, orderBy createdAt DESC | organizerId ASC, createdAt DESC |
| bookings | owner + status, createdAt DESC | organizerId ASC, status ASC, createdAt DESC |
| bookings | admin status, createdAt ASC | status ASC, createdAt ASC |
| bookings | admin room + startAt range | roomId ASC, startAt ASC |
| bookings | admin status + startAt range | status ASC, startAt ASC |
| supportTickets | orderBy lastActivityAt DESC | single-field lastActivityAt |
| supportTickets | status + lastActivityAt DESC | status ASC, lastActivityAt DESC |
| users | role + displayName | role ASC, displayName ASC |
| comments/history | createdAt / version ASC | single-field |

Комбінації фільтрів поза таблицею не обіцяти без відповідного індексу. У `firestore.indexes.json` зберігати всі необхідні composites; не покладатися на ручні console links. Exempt великі description/body і occupancy.slots від індексації, якщо вони не використовуються в query.

Для календарного вікна `[windowStart, windowEnd)` читати події з `startAt >= windowStart - 6h` і `startAt < windowEnd`, потім залишати `endAt > windowStart`. Так враховуються події, що почалися напередодні. Це коректно лише за обов’язкового maxDuration=6h. Обидві межі переводяться з Kyiv у UTC. Читання порціями: UI не має мовчки показувати неповний календар після першої сторінки; показати «Завантажити ще»/ознаку неповноти або дочитати bounded window з контролем квоти.

Admin dashboard: bounded pending list плюс count aggregation після перевірки актуальної підтримки/вартості або чесні лічильники «у завантаженому періоді». Не підтримувати незахищені глобальні counters і не називати обмежений список повним count.

### 6.1 Уточнення schema для обов’язкового audit room/user

Щоб не залишати необов’язковий журнал, остаточна schema доповнюється так:

- `rooms`: `revision:int` (create=1, кожний update +1), `lastAuditId:string`.
- `users`: `adminRevision:int` (self-create=0), `lastAdminAuditId:string|null` (self-create=null).
- `adminAudit`: додатково `revision:int`, `before:map`, `after:map`. Для room map містить лише name/isActive/capacity/sortOrder/locationLabel/description; для user — лише isDisabled. Поля з інших сутностей заборонені.
- Room mutation завжди атомарно створює audit з новим random ID та записує його pointer у room. User displayName update не є admin mutation; лише зміна isDisabled підвищує adminRevision і потребує audit.
- Rules звіряють actor=request.auth.uid, at=request.time, revision, before/after, entityId та pointer через getAfter. Audit create без відповідної зміни сутності заборонено; повторний ID не може перезаписати існуючий audit.
- Публічний room містить лише непрозорий lastAuditId, без actor UID. Admin audit не публічний.
- Bootstrap role через Console/Admin SDK записується в операційний журнал власника; це окремий trusted workflow, не клієнтська Rules-операція.

## 7. Конфлікти та атомарність бронювання

### 7.1 Бізнес-формула

Інтервали напіввідкриті: `[startAt, endAt)`. Для тієї самої кімнати конфлікт існує тоді й лише тоді, коли:

```text
newStart < existingEnd AND newEnd > existingStart
```

Події 10:00–11:00 та 11:00–12:00 сумісні. Конфліктують лише approved-події, крім тієї самої bookingId при редагуванні. Різні кімнати незалежні.

Query «знайди перетини → якщо немає, створи документ» не гарантує відсутність гонки. Rules не можуть виконати довільний query колекції й довести, що немає перетинів. Mutex, який клієнт може обійти записом booking напряму, теж не захист. Тому authoritative constraint — occupancy + атомарна взаємна перевірка Rules.

### 7.2 Обчислення slots

1. UTC instant має лежати на межі 30 хвилин, без секунд/мілісекунд. Local Kyiv choices будуються так, щоб однозначно відповідати UTC instant.
2. Для кожного 30-хвилинного slot у `[start,end)` визначити UTC 6-hour block і slot index 0..11.
3. За duration ≤6h подія торкається максимум двох blocks. Кінець рівно на межі наступного блока не додає його, оскільки end виключний.
4. old/new event разом торкаються максимум чотирьох room/block документів. RoomId є частиною шляху; однакові blockId в різних кімнатах не об’єднуються.
5. `occupancyBlockIds` не є довіреним input: Rules звіряють точне очікуване число/порядок блоків, start/end boundaries і canonical ID. Перший block містить start; останній — instant безпосередньо перед end. Не приймати пропущені блоки, довільні IDs чи дублікати.

У Dart одна pure implementation генерує desired occupancy. Rules мають незалежну еквівалентну перевірку; тести порівнюють їх поведінку на boundaries. Константи slot/block/maxDuration фіксуються як schema v1. Зміна кроку потребує міграції й нового набору тестів, а не тільки зміни UI.

### 7.3 Транзакція approve / admin create / reschedule / cancel

```text
allocate bookingId / historyId before transaction (when creating)
runTransaction:
  read current booking (or absence), actor profile, relevant room
  assert expectedVersion and allowed transition
  compute old occupied blocks if old.status == approved
  compute new occupied blocks if new.status == approved
  read every distinct old/new occupancy document before any write
  for each old occupied slot:
    require stored owner == bookingId; remove ownership
  for each new occupied slot:
    require owner empty OR owner == bookingId; set owner = bookingId
  write changed occupancy documents, preserving every unrelated slot
  write booking version +1 and server audit timestamps
  create immutable history with the same version
  create/update public projection iff approved, otherwise delete existing projection
commit
```

Усі reads — перед writes. Всередині callback немає toast, email, navigation або іншого зовнішнього side effect: Firestore може повторити callback. UI реагує лише на завершення Future. На конфлікт повернути `bookingConflict`; на version mismatch — `staleVersion` і запропонувати перечитати дані, а не мовчки затирати рішення іншого MI.

Повтор мережевого запиту не створює дубльованих booking: ID генерується один раз на спробу користувача й повторно використовується; якщо відповідь загубилася, спочатку перечитати цей ID. Для status commands очікувана version запобігає подвійному переходу. Client offline mutations для бронювань заборонені: транзакція має завершитися online, інакше UI не показує «Схвалено».

Скасування звільняє тільки slots із власним bookingId. Якщо invariant пошкоджено — не перезаписувати чужі slots, заблокувати команду й показати MI помилку цілісності. Відновлення — окремий явний owner workflow, не автоматичне «виправлення» даних браузером.

### 7.4 Вимоги до Security Rules occupancy

Rules реалізують обидва напрями доказу:

**Booking write → occupancy/public/history.** Для approved стану всі потрібні slots у `getAfter` occupancy належать цій bookingId. При виході з approved або перенесенні slots старого інтервалу поза новим більше не містять цю bookingId. Перевірити максимум чотири blocks; оновлення public projection та history обов’язкові. Pending не може мати власних locks. Правильність часу/room/transition перевіряється незалежно від UI.

**Occupancy write → booking.** `lastMutationBookingId` вказує на booking, який дійсно змінює version у цій атомарній операції. Прочитати його before/after. Дозволено змінити лише slots старого/нового approved інтервалу цього booking у цій кімнаті/блоці. Старі slots мають належати bookingId; нові мають бути вільними або належати тому самому booking. Решта slots повинні бути абсолютно незмінними. Заборонити крадіжку, довільне очищення, forged block, подвійну операцію різних booking в одному block write, create orphan lock і delete block.

Rules не мають довільних циклів: для 12 slots використати явно розгорнуті однакові перевірки `s00..s11` з малими helpers; не покладатися на псевдокод loop як на валідний Rules syntax. Новий документ починається з логічно порожніх slots, існуючий зберігає всі сторонні значення. Метадані updatedBy/time звіряти з auth/request.time.

Допустимий клієнтський actor: admin для approve/reschedule; organizer тільки для cancel власного booking з відповідним дозволеним переходом. Developer write occupancy заборонено.

**Обов’язковий технічний gate Stage 2:** довести цю схему в Firestore Emulator ще до повної форми бронювання. Перевірити межі Rules: 10 document access calls на окрему операцію, 20 на транзакцію/batch, а також expression/function limits. Обрахувати worst case old/new room + four blocks + role/room/public/history, включаючи правила кожного write. Не припускати необмеженого кешування викликів і не вважати теоретичний підрахунок заміною emulator test. Якщо схема не вкладається — оптимізувати helpers/пакет операцій зі збереженням атомарності; якщо це неможливо, Stage заблокований до явної архітектурної зміни. Заборонено замінювати серверну гарантію клієнтською перевіркою.

### 7.5 Переходи booking

| Поточний | Новий | Хто / умова |
|---|---|---|
| відсутній | pending | organizer verified/active, owner=self; admin може створити заявку |
| відсутній | approved | admin, locks + public + history |
| pending | pending | owner або admin, editable fields, version+1 |
| pending | approved | admin, active room, майбутній час, відсутній конфлікт |
| pending | rejected | admin, обов’язкова причина |
| pending | cancelled | owner до start або admin |
| approved | approved | admin edit, атомарне перенесення за потреби |
| approved | cancelled | owner до start або admin |
| rejected/cancelled | будь-який | заборонено; нова заявка має новий ID |

Для approval перевірити startAt > request.time; для нового/перенесеного event — також горизонт 180 діб. MI може виправити текст минулої події, але не пересувати минулу подію в інший інтервал. MI може скасувати помилкову минулу подію. CreatedAt/createdBy/organizerId не змінюються. Rejected не перетворюється на approved одним кліком.

## 8. Часові зони та валідація

- Бізнес-зона — IANA `Europe/Kyiv`. Не hardcode UTC+2/UTC+3 і не використовувати `DateTime.toLocal()` для відображення подій.
- У базі UTC Timestamp, у forms — Kyiv wall time з явним підписом зони. Для ambiguous DST time запропонувати два варіанти з UTC offset; для nonexistent time відхилити значення з поясненням. Автоматичне мовчазне зміщення неприпустиме.
- Обчислювати реальну тривалість за UTC instants. Для календарних дат/month boundaries спочатку побудувати Kyiv boundaries, потім UTC. Доба не завжди 24 години.
- Відображення: `dd.MM.yyyy`, 24-hour `HH:mm`, українські назви днів/місяців.
- Trim текст, зберегти внутрішні переноси; title без порожнього/whitespace-only значення. Перевірки client і Rules узгоджені, включаючи обмеження довжини та типів.
- Password policy налаштувати в Auth і відобразити актуальні вимоги; не реалізовувати власну базу паролів. Підтвердження email перевіряти через auth token claim, після verification — refresh token.
- Status/role/type — тільки allowlisted values. Відсутні й зайві поля, null там де заборонено, неправильні numeric types, довільні timestamps відхиляються Rules.
- `createdAt == request.time` при create; `updatedAt == request.time` при update (використовувати serverTimestamp). Незмінні createdAt/createdBy не переписувати.
- Не відображати raw HTML із Firestore. Посилання, якщо додаватимуться, тільки з безпечними схемами; для MVP текст без довільного HTML.

## 9. Routing та екрани

Використати `go_router` із path URLs та Hosting SPA rewrite. Не допускати open redirect через довільний external returnTo.

| Route | Доступ / призначення |
|---|---|
| `/` | публічна головна: короткий опис, найближчі події, CTA календаря |
| `/calendar?date=YYYY-MM-DD&room=ID&view=month` | публічний календар, shareable фільтри |
| `/events/:id` | public event details; для absent/cancelled — нейтральне «Подію не знайдено або знято з публікації» |
| `/rooms` | active locations |
| `/login`, `/register`, `/reset-password` | Auth forms |
| `/verify-email` | verification/resend із cooldown |
| `/my/bookings` | organizer: заявки та статуси |
| `/my/bookings/new`, `/my/bookings/:id`, `/my/bookings/:id/edit` | власні заявки |
| `/admin` | MI dashboard |
| `/admin/bookings`, `/admin/bookings/:id`, `/admin/events/new` | moderation/details/create |
| `/admin/calendar` | approved/pending з чіткими відмінностями |
| `/admin/rooms`, `/admin/users` | management |
| `/support`, `/support/new`, `/support/:id` | admin/developer, new лише admin |
| `/forbidden`, unmatched route | зрозумілі 403/404 UI |

Під час Auth/profile loading не миготіти login чи admin screen; показувати session loading. Deep link зберігається після login лише якщо це дозволений внутрішній маршрут. Після logout очищати приватний Riverpod state і підписки; browser back не показує приватних даних із попередньої сесії. Відсутній profile/disabled/error — окремі стани, не нескінченний spinner.

## 10. UI/UX та доступність

- Ширина <600 px: agenda за днями, одна колонка, нижчі пріоритети в деталях. 600–1023 px: compact month/list. Від 1024 px: місячна сітка та панель фільтрів. Breakpoints — стартове рішення, перевірити фактичний overflow.
- На 320 px не має бути горизонтального scroll сторінки, обрізаних форм або недоступних дій. Admin tables на mobile перетворюються на cards/list.
- Calendar: «Сьогодні», попередній/наступний період, вибір дати, кімнати, видимий Kyiv zone label. Кольору недостатньо для статусу — також текст/іконка.
- Деталі: title, room/location, Kyiv date/time, description. Контакти організатора не показувати.
- Form: labels, пояснення публічності, field errors біля поля, збереження введеного тексту при network error. На конфлікт показати room/time та запропонувати змінити інтервал. Не показувати приватні дані чужого booking.
- Loading: skeleton або індикатор конкретного списку; submit disabled під час відправки. Не блокувати весь застосунок для локальної дії.
- Empty: календар без подій, немає кімнат, немає власних заявок, немає tickets — різні повідомлення й доречні CTA.
- Error: retry для fetch, зрозумілий offline/quota/permission стан; не показувати raw stack trace. Quota failure не маскується під «немає подій».
- Confirm для cancel/archive; reject потребує причини. Destructive дію не виконувати одним випадковим натисканням.
- Keyboard navigation, видимий focus, logical tab order, Semantics labels, текстовий equivalent іконок; dialog повертає focus. Орієнтир WCAG AA: контраст звичайного тексту ≥4.5:1, touch targets близько 48 px, text scaling 200% без втрати функцій.
- Перевірити screen reader основних forms, status announcements та заголовків. Повний WCAG-аудит не входить, базова доступність входить.
- Не додавати складні анімації, drag-and-drop calendar чи редактор layout до MVP.

## 11. Support workflow та email

### 11.1 Статуси ticket

`new → accepted → in_progress → done`. Developer також може `new/accepted → rejected`; `done/rejected → closed`. MI може `done/rejected → closed` або повернути `done → accepted` із обов’язковим коментарем «проблема лишилася». Developer може `done/closed/rejected → accepted` із коментарем для reopen. Інші переходи заборонені. Ticket фізично не видаляється.

Кожен status change і priority change додає history. Коментар MI на existing ticket та створення ticket — окремі джерела email. Коментар developer не викликає лист самому developer. Новий ticket не повинен одночасно генерувати дубль «новий коментар», якщо body представлено первинним повідомленням.

### 11.2 Stage 8 — обов’язкова перевірка здійсненності

Auth+Firestore+static Hosting самі не запускають довільну фонову email-відправку. Безкоштовний provider не розв’язує питання trusted execution, retries і зберігання секретів. SMTP/API secret у Flutter заборонений. Firebase email/password verification/reset — окрема Auth-функціональність, вона не замінює support notifications.

На Stage 8 перевірити актуальні умови щонайменше двох реалістичних provider + sender схем. Порівняти: free quota, відсутність recurring charge/trial expiry, card requirement, hard cap/overage, sender/domain verification, чи потрібний придбаний домен, delivery/retry support, безпечне зберігання secrets, доступ до Firestore та abuse protection. Записати дату і посилання в ADR. Не вибирати provider зараз.

Бажаний результат — керована інтеграція без власного довгоживучого сервера, без billing і без клієнтських секретів, що перевіряє справжнє створення ticket/comment. Якщо вона потребує нового trusted server-side runtime поза вихідним стеком, це архітектурне розширення: підготувати конкретну схему й отримати явне рішення користувача перед підключенням. Не додавати Render/API backend мовчки.

Умови готовності email:

- Recipient фіксований конфігурацією developer, browser не може його підмінити.
- Джерело — підтверджений admin ticket/comment; не довіряти довільному webhook payload або authorRole.
- Idempotency key: `ticket:{id}:created` / `ticket:{id}:comment:{commentId}`; retries не повинні створювати необмежені дублікати. Exactly-once між Firestore і зовнішнім provider без його idempotency не обіцяти; описати duplicate window і захист.
- Failure email не відкочує ticket/comment. Retry із bounded exponential backoff, maximum attempts і видимим failed state; secrets та повний текст не логуються.
- Лист містить тип події, назву ticket і secure app link; приватні деталі вмісту мінімізувати. Доступ до link усе одно вимагає login/role.
- Acceptance: developer отримує реальний тестовий лист для ticket та для admin comment; developer comment не надсилає лист; повтор не дає неконтрольованих дублікатів.

Якщо жодна безпечна схема не відповідає $0/без billing/без нового runtime, Stage 8 має статус **blocked** із ADR та готовим adapter contract. In-app unread indicator або manual mailto можуть бути тимчасовим доповненням, але не вважаються автоматичним email. Реліз без email можна назвати «core MVP без email» лише після явного прийняття цього відхилення користувачем; повний MVP не позначати готовим.

## 12. Firebase config, безпека та бюджет

### 12.1 Середовища

Default local development — Emulator Suite з demo project ID. Production — окремий явно вказаний Firebase project. Якщо існує окремий dev Firebase project, використати alias dev, але не створювати платні середовища. Firestore region обрати до створення бази з урахуванням розташування користувачів; записати вибір і наслідки в README. Не вигадувати існуючий project ID або region.

Firebase Web config (`apiKey`, `authDomain`, `projectId`, `appId`, `messagingSenderId`, optional storageBucket) є публічними ідентифікаторами клієнта; відповідний `firebase_options.dart` дозволено комітити за прийнятою політикою репозиторію. Це не service account credential. Захист забезпечують Rules/Auth, а не приховування config. API key має бути обмежений потрібними Firebase APIs; не використовувати цей ключ для сторонніх платних Google APIs.

Секрети: service-account JSON/private keys, SMTP credentials, email provider private API key, access/refresh tokens, deployment credentials. Не комітити; зберігати лише у відповідному secret store/локальному excluded файлі. `.env.example` містить імена та placeholders, не реальні значення. Firebase config через `dart-define` — спосіб вибору середовища, не захист секрету.

Emulator flag явний: `--dart-define=USE_FIREBASE_EMULATORS=true`. У production build він false; startup перевіряє некоректні комбінації. Firebase.initializeApp виконується перед repository use; connect emulators — до першого доступу до Auth/Firestore. Не перемикатися на production автоматично.

### 12.2 Rules baseline

Default deny для невідомих paths. Розділяти get/list/create/update/delete. Немає blanket `allow read, write: if request.auth != null`. Валідація allowlist, immutable fields, role, owner, disabled, verified email, transitions, server time, version та cross-document invariants.

Web SDK не може обійти Rules; Admin SDK може, тому trusted utilities не роздавати користувачам. App Check оцінити на Stage 9 за актуальною підтримкою й безкоштовністю: це додатковий захист від abuse, не заміна Rules або достатній rate limit. Якщо не ввімкнено — документувати, а не удавати повний захист від автоматизованого spam.

Для приватних екранів за замовчуванням не вмикати persistent Firestore disk cache на спільному браузері. Logout очищає app state; не зберігати private ticket content у localStorage. Секрети/персональні дані не потрапляють у analytics/crash logs.

### 12.3 Перевірені тарифні передумови

Станом на дату документа офіційна документація Firebase вказує вимогу Blaze для Cloud Storage, чинну з 2026-02-03. Тому MVP **без вкладень і без firebase_storage**. Статичні ілюстрації застосунку можуть бути bundled assets на Hosting. Cloud Functions не закладати як безкоштовний Spark dispatcher. Firebase Hosting — саме static Hosting, не Firebase App Hosting.

Точні актуальні квоти Auth/Firestore/Hosting повторно перевірити на Stage 1 і Stage 11; зберегти таблицю з датою в `docs/operations.md`. Не гарантувати $0 за довільного трафіку. Не додавати billing для обходу quota errors. Контроль: bounded queries, pagination, unsubscribe listeners, відсутність polling у background tab, відсутність індексації великих непотрібних полів. Budget alerts на paid plan, якщо він колись буде окремо погоджений, не є жорстким spending cap.

## 13. Команди та спільні перевірки

Команди нижче виконуються з кореня репозиторію, якщо не вказано інше. Це вимоги до майбутньої реалізації, не твердження про вже виконані тести. Firebase project ID у production commands замінюється лише на перевірений реальний ID. Toolchain prerequisites: Flutter stable із Web, сумісні Node.js LTS, Firebase CLI, FlutterFire CLI, Java для Emulator Suite за актуальною документацією.

Базовий набір **F** після змін Dart:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Під час роботи форматувати `dart format lib test`, а перевірку використовувати після цього. Після появи `integration_test` включити його в format check. Якщо test directory ще не існує, спочатку додати доречний bootstrap smoke test, а не оголошувати порожній запуск успішним.

Набір **R** із Stage 2 — Rules та транзакційні integration tests у `rules-tests` (Node test runner + `@firebase/rules-unit-testing`, pinned lockfile):

```powershell
npm --prefix rules-tests ci
firebase emulators:exec --only auth,firestore --project demo-dacha "npm --prefix rules-tests test"
```

У Stage 2 створити script `test` і гарантувати, що він вимагає emulator host та завершується з помилкою без emulator. Використовувати test contexts, fixtures і Admin bypass тільки для seed тесту. Ті самі fixtures не повинні опинитися в production. Emulator tests не доводять, що production composites deployed; це окрема перевірка Stage 11.

Набір **B**:

```powershell
flutter build web --release
```

Якщо конфігурація використовує обов’язкові public defines, README містить точний доповнений варіант B; простий B не повинен збирати застосунок із неправильним production ID. Local smoke:

```powershell
firebase emulators:start --only auth,firestore --project demo-dacha
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Останні дві команди виконуються у різних терміналах. Long-running emulator/UI processes — ручна перевірка, не тест із самостійним завершенням.

## 14. Покрокова реалізація

### Stage 1 — Bootstrap + Firebase

**Scope:** працездатний Flutter Web skeleton, вибір середовища та emulator-first setup.

**Tasks:**

1. Прочитати поточний репозиторій, перевірити стан Git і toolchain. Якщо Flutter-проєкт відсутній, створити web-only app із Dart package name `dacha_annonce` у наявній директорії без перезапису README/SPEC/інших файлів. Команда після перевірки: `flutter create --platforms=web --project-name dacha_annonce .`.
2. Додати сумісні базові пакети, `pubspec.lock`, lint config, Material 3 theme, українську localization, базовий Router, 404 та loading/error shell.
3. Firebase bootstrap, demo emulator config, явний environment switch. Для real project виконати FlutterFire config лише за наявності project ID і дозволеного доступу; інакше документувати ручні дії.
4. Створити `firebase.json`, `.firebaserc` без вигаданого production alias, deny-all Rules, порожній index config. Не залишати test-mode public writes.
5. `.gitignore` для build/cache/secrets, `.env.example` за потреби; bootstrap widget smoke test; README setup і stage-status.
6. Перевірити Spark/Hosting/Storage умови, записати дату/посилання й відсутність billing.

**Не робити:** bookings, реальні users/rooms, support, production deployment, усю майбутню folder hierarchy без коду.

**Definition of Done:** app відкривається локально; routing/404 працюють; Auth/Firestore прив’язуються до emulator; помилкова конфігурація видима; production не використовується випадково; deny-all Rules завантажуються; секретів немає. Якщо real Firebase project ще не створено, це явна незавершена ручна передумова, а не вигадана інтеграція.

**Перевірки:** `flutter --version`, `flutter doctor -v`, `node --version`, `firebase --version`, `java -version`, `flutter pub get`, F, B; emulator startup та local Chrome smoke.

### Stage 2 — Data model + repositories

**Scope:** schema/DTO/contracts, базові repositories, Rules test harness і доказ anti-conflict architecture.

**Tasks:**

1. Domain models/enums, converters, UTC/Kyiv helpers, injected Clock; опис schema в docs/data-model.md.
2. Repository interfaces і Firebase adapters для rooms/public events/profiles, command contracts для booking/support; fakes для unit/widget tests. Нереалізовані команди явно кидають controlled unsupported error, не повертають fake success.
3. Індекси query contract, rules helpers та allowlists для model paths. Emulators seed для active/inactive rooms, organizer/admin/developer/disabled users, кількох approved/pending подій.
4. Реалізувати мінімальний транзакційний booking engine, необхідний для перевірки occupancy, навіть до створення форм Stage 5. Перевірити create approved, overlapping approval, move між кімнатами/blocks, cancel, mirror та history.
5. Додати Node Rules tests: client cannot forge owner/role, reserve без booking, approved без locks, public mirror injection, часткове очищення old slots. Прямі malicious writes мають fail.
6. Задокументувати worst-case Rules document accesses/expression budget; test максимальних інтервалів і перенесення з двома old та двома new blocks. Якщо не проходить — не переходити далі.
7. Audit room/user schema й атомарність; seed scripts жорстко перевіряють demo/emulator environment.

**Не робити:** повноцінні екрани moderation/support, email, production data migrations, прихований backend для обходу gate.

**Definition of Done:** round-trip DTO/validation tests успішні; immutable поля захищені; query shapes та indexes описані; anti-conflict proof реалізований і проходить, включаючи simultaneous competing approvals. Не досить лише намалювати алгоритм.

**Перевірки:** F, R; seed emulator і read fixtures; цільові unit tests UTC/slots/DTO; перевірка відсутності network fallback.

### Stage 3 — Public calendar

**Scope:** корисна публічна частина на read-only repositories.

**Tasks:**

1. Головна, rooms list, month/agenda calendar, event details та shareable date/room filters.
2. Range pagination із lookback 6h, midnight/DST handling; стабільний порядок подій.
3. Loading/error/empty/not-found; inactive rooms не потрапляють у public room list; історичні event room snapshots відображаються.
4. Адаптивність 320/768/1280 px, keyboard access, labels, text scaling.
5. Security tests: visitor не читає bookings/users/tickets, public projection не містить private fields; довільна room query без active condition не має випадково пройти.

**Не робити:** login/book forms, admin capabilities, платний calendar package, events із приватної колекції.

**Definition of Done:** anonymous user бачить тільки approved проєкції; filters/deep links і межі дат коректні; offline/error не показує фальшивий empty state; календар не приховує неповноту pagination.

**Перевірки:** F, R, B; manual mobile/desktop calendar із emulator fixtures, public deep-link refresh і cancel projection disappearance.

### Stage 4 — Auth + roles

**Scope:** Auth flows, профілі та захищений routing.

**Tasks:**

1. Email/password register/login/logout/reset/verification; українські повідомлення, cooldown resend, safe returnTo.
2. Створення organizer profile із recovery після часткового signup; claim refresh після verification.
3. Riverpod session/profile state, guards organizer/admin/developer, disabled handling та invalidation subscriptions on logout.
4. Rules для own profile update, заборона role escalation, чужого UID та isDisabled change користувачем.
5. Документований ручний bootstrap першого MI/developer; перевірити IAM boundary, не робити admin signup UI.
6. Auth tests і profile failure/reload scenarios.

**Не робити:** social login, phone/SMS, довільне призначення ролей з UI, зберігання email/password у власній базі.

**Definition of Done:** працюють Auth flows на emulator; verified state потрібний для майбутніх booking writes; усі ролі мають правильні guards; direct API role escalation denied; logout прибирає приватні дані.

**Перевірки:** F, R, B; manual login/logout/reset/verification на Auth Emulator та role guards; реальна доставка Auth email — окремий production smoke Stage 11.

### Stage 5 — Booking

**Scope:** organizer journey та завершення booking service.

**Tasks:**

1. Own bookings list/details/create/edit pending/cancel; поля room/title/description/Kyiv start/end.
2. Validation: активна кімната, verified account, 30-minute grid, ≤6h, ≤180 діб, future start; попередження про approved overlap.
3. Pending create/update з version/history без occupation; повторний submit зберігає ID.
4. Organizer cancel approved атомарно звільняє locks та видаляє public mirror; cancel pending не змінює locks.
5. Stale version, network failure, permission lost, conflict error; введений текст не губиться.
6. Узгодити готовий Stage 2 engine з production repository adapter, без дублювання різних алгоритмів.

**Не робити:** recurring/multi-room, organizer self-approve, редагування approved організатором, offline success queue.

**Definition of Done:** organizer проходить повний дозволений цикл; не змінює чужі заявки; pending не блокує час; cancel зберігає invariant; повторний submit не плодить дублікати.

**Перевірки:** F, R; unit interval/validation tests, widget form tests, emulator сценарій create→pending edit→cancel та seeded approved→cancel; offline failure/manual retry.

### Stage 6 — MI admin

**Scope:** операційна адмінка MI.

**Tasks:**

1. Dashboard, pending queue, booking detail із history, approved/pending calendar із фільтрами.
2. Approve/reject/cancel, mandatory reject reason, admin create approved, edit metadata, atomic room/time reschedule.
3. Room create/edit/archive з audit; existing approved events зберігаються при archive.
4. Users overview і app disable/enable лише organizer; жодної role promotion.
5. Конкурентне схвалення з двох сесій, stale version handling, room inactive change під час approval.
6. Заборонити started/past reschedule та дозволити безпечне виправлення тексту; history з коректним actor.

**Не робити:** права developer на MI bookings, bulk approve, drag-and-drop, Auth account deletion, автоматичне скасування всіх подій при room archive.

**Definition of Done:** два MI не можуть схвалити перетин; невдала reschedule не втрачає старе бронювання; projection/history/locks атомарні; rooms/users edits аудіюються.

**Перевірки:** F, R, B; дві browser sessions на emulator, overlap/boundary/different-room scenarios, room/user permission tests, mobile admin layout.

### Stage 7 — Support

**Scope:** tickets, comments, transitions, history.

**Tasks:**

1. `/support` list/filter/details та MI create bug/feature/feedback.
2. Developer status/priority controls; MI close/reopen в дозволених переходах; обов’язковий пояснювальний comment при reopen.
3. Append-only comments, transactional ticket version/history/lastActivityAt; pagination comment history.
4. Правильні authorRole/UID/server times, role-limited Rules, loading/error/empty.
5. UI пояснює, що автоматичний email ще не підключено; optional unread state локальний, без обіцянки доставки.

**Не робити:** attachments, rich text, email provider configuration, chat presence/typing, редагування старих comments/history.

**Definition of Done:** MI створює й коментує, developer опрацьовує; organizer/visitor повністю denied; одночасні comments не губляться; кожен перехід має history; forged actor/rewrite history відхиляються.

**Перевірки:** F, R; widget status/permission tests; emulator MI→developer→MI cycle, concurrent comments, reopen reason і pagination.

### Stage 8 — Email

**Scope:** актуальна оцінка й безпечна інтеграція сповіщень developer.

**Tasks:**

1. Дослідити current provider + trusted sender умови за розділом 11; не вибирати на основі застарілих «free tier» оглядів.
2. Створити `docs/decisions/008-email.md`: comparison, costs/quotas, account/domain prerequisites, trigger, authentication, secret storage, retry/idempotency та failure UX.
3. Якщо рішення потребує зміни архітектури — підготувати конкретний варіант і чекати явного рішення перед підключенням. Якщо допустиме — реалізувати adapter та мінімальний trusted integration.
4. Захистити fixed recipient, перевірку source event, notification metadata, retries і visible failure. Не змінювати успішність ticket save через delivery failure.
5. Real email test на адресу developer, надану користувачем; не вигадувати recipient. Документувати операційні дії й quotas.

**Не робити:** SMTP у Flutter, credentials у build, довільний public email relay, платний extension/Blaze, browser-only send як гарантовану фонову доставку.

**Definition of Done:** або всі email acceptance checks розділу 11 пройдені з реальною доставкою й підтвердженим $0 режимом, або чесний blocked status з причиною. «Adapter написано» не означає email done.

**Перевірки:** F за змін Dart, R за змін Rules, adapter/sender tests фактично обраного runtime; в ADR записати точні команди. Manual new ticket/admin comment/developer comment, retry duplicate, invalid source, offline browser after ticket save, provider failure. Не вигадувати universal provider CLI до вибору.

### Stage 9 — Security hardening

**Scope:** перевірка всього permission surface та production readiness.

**Tasks:**

1. Звірити permission matrix з get/list/create/update/delete для всіх paths; catch-all deny.
2. Негативні прямі writes: escalation, owner swap, forged audit/time/author, extra fields, invalid transitions, orphan locks, public projection leakage, disabled users.
3. Повторно перевірити transactional call/expression limits на найбільшій операції. Валідація Rules не покладається лише на те, що app правильно пише.
4. Переглянути private cache/logout/logging, API restrictions, auth domains, email sender abuse. Оцінити App Check без billing dependency.
5. Secret scan поточних файлів і, якщо репозиторій має історію, доступної Git history без виведення значень секретів; при знаходженні описати необхідну rotation.
6. `docs/security.md`: invariants, threat model, IAM/Admin SDK boundary, залишкові ризики spam/quota.

**Не робити:** переписування стеку, формальну сертифікацію, платний security service, приховане ввімкнення billing.

**Definition of Done:** усі недозволені дії denied; дозволені journeys не зламані; немає відомого обходу anti-conflict/public privacy; документовані залишкові ризики не приховують критичну вразливість.

**Перевірки:** F, R, B; repo secret-check за доступним інструментом із зафіксованою командою, manual logout/back/profile revocation; production ще не змінювати.

### Stage 10 — Tests

**Scope:** закрити прогалини у регресійному покритті, що вже створювалося в попередніх Stage.

**Tasks:**

1. Звести таблицю вимога→тест; пріоритет anti-conflict/privacy/roles/transitions/time, а не відсоток coverage заради числа.
2. Unit tests: UTC/Kyiv DST, midnight/month lookback, adjacent intervals, full/partial overlap, same booking edit, limits, DTO unknown status.
3. Rules/concurrency: одночасний approve, update-vs-cancel, room archive-vs-approve, owner/role forgery, missing mirror/history, orphan/steal/clear lock, максимальна reschedule між 4 blocks.
4. Widget: forms, session states, empty/error, keyboard labels, responsive critical screens.
5. Emulator-backed journeys: organizer submission→MI approve→public visible→cancel hidden; support create→comment→done→reopen; email boundary mock і окремий реальний Stage 8 smoke.
6. Документувати відтворюваний web E2E harness, сумісний із зафіксованим Flutter SDK. Browser E2E може використовувати підтримуваний Flutter Web driver/ChromeDriver; вибір та exact command закріпити в README, без обіцянки непідтримуваного `flutter test -d chrome integration_test`.

**Не робити:** тести, які лише копіюють implementation, flaky sleep-based тести, реальні production writes, платний CI або необов’язковий performance lab.

**Definition of Done:** критична матриця пройдена; concurrency test підтверджує рівно один успішний competing approval і цілісність усіх документів; немає необґрунтованих skipped критичних тестів. E2E command відтворюється з чистого setup.

**Перевірки:** F, R, B; `flutter test --coverage`; exact E2E command із README після створення harness. Не оголошувати coverage достатньою лише за високим числом.

### Stage 11 — Deployment

**Scope:** відтворюваний release на Firebase Hosting та операційна документація.

**Tasks:**

1. Повторно перевірити тарифи, реальний project ID, region, Spark/no billing, Auth email/password і authorized domains; production config не вказує на emulator.
2. Hosting `public: build/web`, SPA rewrite `** → /index.html`, asset caching без stale app shell. Flutter router path strategy узгодити з rewrite; security headers перевірити на сумісність із Flutter renderer/Firebase, не копіювати CSP навмання.
3. Deploy Rules/indexes перед UI, дочекатися готовності indexes, потім Hosting. Не використовувати blanket `firebase deploy`, який може зачепити сторонні сервіси.
4. Підготувати release checklist, rollback UI та Rules, owner bootstrap, ручний seed rooms без demo accounts, smoke plan і backup/recovery procedure.
5. Публікувати лише після прямої команди користувача. Якщо команди немає — завершити підготовку й явно позначити deployment pending approval, не називати production запущеним.
6. Після дозволеної публікації перевірити HTTPS/deep links/public privacy/Auth email/MI flow з контрольованими тестовими даними і документованим cleanup.

**Не робити:** custom domain purchase, App Hosting, Cloud Functions, billing activation, commit/push, автоматичний paid backup/PITR, destructive production seed.

**Definition of Done:** конфігурація й документація готові; для статусу deployed потрібні фактичний URL, успішний deploy, smoke і запис версії. Розрізняти «готово до deploy» та «опубліковано».

**Перевірки:** F, R, B; локальний `firebase emulators:start --only hosting --project demo-dacha`. Лише після явного дозволу:

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project ACTUAL_PROJECT_ID
firebase deploy --only hosting --project ACTUAL_PROJECT_ID
```

`ACTUAL_PROJECT_ID` — placeholder, не запускати буквально. Перед другою командою перевірити readiness indexes. Ручний production smoke не замінює emulator security tests.

### Stage 12 — Polish

**Scope:** доведення погодженого MVP до зручної щоденної роботи.

**Tasks:**

1. Переглянути реальні MI/organizer journeys, українські тексти, помилки, порожні стани, loading і confirmations.
2. Responsive/keyboard/screen reader/text scaling smoke на ключових екранах; прибрати overflow і зайві дії.
3. Оптимізувати очевидні зайві reads/listeners/rebuilds; перевірити release bundle/час першого відкриття без обіцянки HTML SEO parity для Flutter Web.
4. Додати лаконічні інструкції MI та developer, screenshots лише з безпечними демонстраційними даними.
5. Звірити фінальний MVP checklist, stage-status, ADR, README, відомі обмеження та backlog.

**Не робити:** нові великі features, recurring, redesign architecture, приховане розширення ролей, видавання deferred email за готовий.

**Definition of Done:** повний acceptance checklist пройдено або конкретні відхилення явно прийняті користувачем; документація відображає фактичну реалізацію; критичних UX/security/conflict defects немає.

**Перевірки:** F, B; R якщо змінені дані/Rules, цільові regression tests для виправлень; manual 320/768/1280 px, keyboard, 200% text, MI walkthrough. Не повторювати весь дорогий E2E без змін чи невирішених ризиків.

## 15. Обов’язкова тестова матриця

| Група | Мінімальні кейси |
|---|---|
| Інтервали | adjacent, identical, contained, partial overlap, різні room, midnight, block boundary, 30 min та 6h |
| UTC/Kyiv | зима/літо, spring gap, autumn ambiguity, клієнт у іншій timezone, month boundary |
| Race | два approve одного slot → один commit; reschedule з конфліктом → старий стан збережений; cancel vs edit → version conflict |
| Integrity | approved без lock/mirror/history denied; lock без booking denied; stolen/extra slots denied; forged block ID denied |
| Projection | жодних UID/contact/rejection fields; cancel видаляє проєкцію атомарно; pending не публічний |
| Permissions | visitor/owner/other organizer/admin/developer/disabled/unverified; query constraint bypass denied |
| Audit | server timestamps, immutable creation, version increments, append-only, wrong actor/history denied |
| Support | типи, transitions, коментарі, concurrent comments, reopen із причиною, privacy |
| Email | ticket та MI comment → send; developer comment → no send; retry/idempotency/failure/recipient tampering |
| UX | loading/empty/error/offline, double click, lost response, deep links, logout/back, mobile/keyboard |

## 16. README та операційні вимоги

README повинен дозволити іншому розробнику запустити застосунок без здогадок:

1. Призначення, стек і фактичні версії Flutter/Dart/Node/Firebase CLI/Java, prerequisites для Windows.
2. Setup із чистого clone, `flutter pub get`, package installation Rules tests, emulator start/seed, demo identities тільки локально.
3. Public Firebase config, середовища/aliases, реальний production project identifier без secrets, правила emulator switch.
4. Команди format/analyze/unit/Rules/E2E/build; очікувані prerequisites та типові помилки.
5. Схема БД, індекси, public/private split, роль bootstrap і application disable semantics.
6. Як MI створює room, опрацьовує заявку, переносить/скасовує event, створює ticket; як developer змінює support status.
7. Особливості Kyiv/DST, крок 30 хв, максимум 6h, pending non-reservation та обмеження MVP.
8. Deployment по кроках, SPA deep links, Auth authorized domains, index readiness, release/rollback.
9. Email фактичний provider/sender, quota, secret placement, real verification, retries, відновлення після збою; якщо blocked — це явно написано.
10. No-cost operations: актуальні квоти й дата перевірки, що робити при quota exhaustion, без автоматичного billing.
11. Backup/recovery: не обіцяти managed backups/export/PITR як безкоштовні. Перед вибором перевірити актуальні вимоги. Для малого MVP можливий явно запущений власником локальний експорт через Admin SDK у приватний файл поза Git, із перевіркою квот/консистентності та restore rehearsal лише в emulator. Звичайний JSON export під час паралельних writes не вважати гарантованим consistent snapshot; потрібне контрольоване вікно без записів. Auth users — окремий об’єкт від Firestore profiles.
12. Зафіксувати retention: автоматичного видалення bookings/support немає; запити на очищення персональних даних опрацьовує власник окремою процедурою, з урахуванням пов’язаних документів та доступів.

`docs/deployment.md` містить конкретну конфігурацію, `docs/operations.md` — quota/backup/incident runbook. Під час restore перевіряти booking→locks→public→history invariant, не просто кількість документів.

## 17. Фінальні критерії MVP

- [ ] Visitor без акаунта відкриває calendar/details/active rooms на desktop і mobile.
- [ ] Публічні документи не розкривають приватні заявки, identities чи support.
- [ ] Organizer реєструється, підтверджує email, входить, відновлює пароль, подає/редагує pending та скасовує власні події.
- [ ] MI має moderation, admin create/edit/reschedule/cancel, rooms/users overview і app disable organizer.
- [ ] Жоден клієнт, включаючи malicious direct API write, не може створити два approved перетини в одній кімнаті в межах визначеної schema.
- [ ] Конкурентні операції, adjacency, Kyiv/DST і транзакційна узгодженість перевірені.
- [ ] Support працює з усіма дозволеними transitions/comments/history, organizer/visitor denied.
- [ ] Developer реально отримує email про ticket і MI comment; або реліз явно позначений core MVP з окремо прийнятим відхиленням щодо email.
- [ ] Security Rules/indexes версіоновані, негативні тести успішні, секретів у Git/browser немає.
- [ ] Loading/error/empty/validation/accessibility та базова responsive behavior реалізовані.
- [ ] Release build і належні перевірки пройдені; фактичний deployment виконано лише за дозволом.
- [ ] README/runbooks дозволяють запуск, bootstrap MI/developer, deployment, rollback і обґрунтоване recovery.
- [ ] Немає підключених платних залежностей/сервісів чи автоматичного billing; актуальні квоти задокументовані.

## 18. Офіційні джерела та повторна перевірка

Перевірено 2026-09-28. Джерела пояснюють можливості платформи; occupancy schema та продуктові межі вище — проєктне рішення, яке потребує власних emulator tests.

- Firebase pricing: https://firebase.google.com/pricing
- Pricing plans: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- Hosting quotas: https://firebase.google.com/docs/hosting/usage-quotas-pricing
- Storage/Blaze requirement: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Transactions, getAfter та atomic Rules limits: https://firebase.google.com/docs/firestore/manage-data/transactions
- Rules conditions та query constraints: https://firebase.google.com/docs/firestore/security/rules-conditions
- Firebase public API keys: https://firebase.google.com/docs/projects/api-keys
- Security checklist: https://firebase.google.com/support/guides/security-checklist

На Stage 1 перевірити актуальні API/сумісність Flutter packages за офіційною документацією; на Stage 8 — email provider і trusted runtime; на Stage 11 — production quotas і deployment prerequisites. Якщо документація змінилася, записати нове рішення в ADR та відобразити істотну зміну scope користувачу.

## 19. Команда для початку реалізації

Приклад наступного запиту до IDE Codex:

> Прочитай AGENTS.md, SPEC.md і поточний код у D:\Projects\dacha-annonce-. Виконай лише Stage 1 — Bootstrap + Firebase. Збережи існуючі файли та незакомічені зміни, не роби commit/push/deploy і не підключай платні сервіси. Перевір результат, дай звіт за протоколом SPEC.md та зупинися.
