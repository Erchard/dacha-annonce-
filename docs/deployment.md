# Firebase Hosting: публічний preview каркаса

Користувач явно дозволив публікацію поточної стартової сторінки 2026-09-28. Це окрема рання публікація каркаса, а не завершення всього Stage 11 або MVP.

Project/site: `dacha-annonce`. Ціль: `https://dacha-annonce.web.app`. Runtime Firebase options — згенерований FlutterFire config, emulator flag false. CLI default alias залишається `demo-dacha`; кожна production-команда містить явний `--project dacha-annonce`.

## Передумови й перевірки

- CLI підтвердив доступ до активного Firebase project та Hosting site `dacha-annonce`.
- Cloud Billing read-only API повернув `billingEnabled: false`. Billing/Blaze не активувалися.
- `flutter build web --release --dart-define=USE_FIREBASE_EMULATORS=false` — успішно.
- `firebase.json`: статичний Hosting з `build/web`, SPA rewrite до index.html, no-cache baseline.
- `npx.cmd --no-install firebase emulators:exec --only hosting --project demo-dacha "node scripts/hosting-smoke.mjs http://127.0.0.1:5000"` — успішно: головна, deep-link 404, повернення на головну, 320 px, без JS помилок та emulator-запитів.
- Flutter analyze, 9 unit/widget tests, 5 config tests та 48 emulator deny-all перевірок пройдені в попередньому виправленні тієї самої Dart реалізації. Dart-код цією публікацією не змінювався.

Команда публікації лише Hosting:

```powershell
npx.cmd --no-install firebase deploy --only hosting --project dacha-annonce --non-interactive --message "Dacha bootstrap preview 2026-09-28"
```

Тільки статичний preview: жодних production data writes, змін Auth, Rules/indexes або платних сервісів. Firestore не використовується для прикладних даних цією сторінкою. Правила/індекси перед повноцінним UI з даними належать подальшому release checklist; цей preview не засвідчує готовність backend permissions або майбутніх функцій.

## Повторна перевірка

```powershell
node scripts/hosting-smoke.mjs https://dacha-annonce.web.app
```

Скрипт відкриває сайт у чистому headless Chrome, перевіряє маршрути та адаптивність; не реєструє користувачів і не записує Firestore дані. Screenshots зберігаються локально в `.tools/qa/screenshots` і не публікуються.

## Rollback та наступні релізи

Firebase Console → Hosting → Release history: обрати попередній успішний реліз і Roll back після окремого дозволу користувача. Якщо попередньої версії не було, rollback не відновить неіснуючий сайт; за потреби окремо погодити заміну стартовою сторінкою або вимкнення Hosting. Не змінювати Rules під час UI rollback.

Перед наступною публікацією знову зібрати production target: browser/emulator smoke може залишити demo build/web, його не публікувати. Повний release MVP потребує всіх критеріїв SPEC: roles/security, real Auth email, Firestore region/rules/indexes, operational runbooks та інших Stage.

Тарифні передумови повторно звірено: [Hosting quickstart](https://firebase.google.com/docs/hosting/quickstart), [Hosting quotas](https://firebase.google.com/docs/hosting/usage-quotas-pricing). Spark має квоти; без billing не вмикається автоматична оплата за їх перевищення. Попередня розбіжність позначень transfer quota між pricing і Hosting guide зберігається в docs/operations.md.

## Результат публікації 2026-09-28

**deployed (bootstrap preview)**: https://dacha-annonce.web.app

Firebase CLI: Deploy complete, hosting release complete. Публічний Chrome smoke — PASS: головна, пряме відкриття `/missing`, повернення на головну, 320 px, без JavaScript помилок та запитів до localhost emulators. Це також підтверджує завершення Firebase bootstrap у Web до показу головної; Auth flows/Firestore permissions не перевірялися і ще не реалізовані як користувацькі сценарії.

Версія: `Dacha bootstrap preview 2026-09-28`, main.dart.js SHA256 `ADE09001BCE62146F0568C9AF078CA517AB16A8A8B72470B857306C6C8B6AD31`. Публікувалися 39 файлів із build/web. Commit/push не виконувалися.

## Наступний прикладний release (ще не виконано)

1. Завершити локальні перевірки README; погодити email-блокер або завершити підключення листів. Поточні результати — docs/stage-status.md.
2. Перевірити у Console саме dacha-annonce: Spark/billing disabled, Firestore region/режим, Email/Password Auth увімкнений; authorized domains включають dacha-annonce.web.app та фактичний домен. Для локального production Auth localhost додається лише за потреби.
3. Перед публікацією перевірити відсутність прикладних документів зі старою schema. Поточна v1 додала lastMutationVersion до occupancy; ранній bootstrap не створював такі documents. За наявності зовнішніх даних спершу окремий план міграції.
4. Зібрати `flutter build web --release` **без** USE_FIREBASE_EMULATORS. Попередній demo build не публікувати. Переконатися, що вихід — build/web і main.dart.js не містить runtime emulator configuration як активного режиму.
5. Лише за прямим дозволом виконати:

```powershell
npx.cmd --no-install firebase deploy --only firestore:rules,firestore:indexes --project dacha-annonce
```

6. Дочекатися Ready для потрібних composite indexes у Console. Emulator не перевіряє цей стан.
7. Лише за дозволом опублікувати Hosting:

```powershell
npx.cmd --no-install firebase deploy --only hosting --project dacha-annonce
```

8. Перевірити public calendar/room/event, deep links, реєстрацію/реальний verification email, організатора й адміністратора на контрольованих записах. Demo seed не запускати. Створення production rooms/тестових даних потребує окремого дозволу; видалення/скасування тестів планується разом із ним.
9. Зберегти release version і відомий попередній Hosting release. UI rollback через Console; Rules/indexes/data — окремі зміни з перевіркою сумісності, не частина автоматичного rollback сайту.

Раніший scripts/hosting-smoke.mjs призначений для історичного bootstrap preview. Актуальний прикладний release перевіряється scripts/browser-smoke.mjs у Emulator; production smoke виконується окремо після дозволеної публікації. Цей checklist не є підтвердженням deployment.

## Тестовий випуск для MI — 2026-09-29

Користувач прямо дозволив привести основний продукт у робочий стан і опублікувати для Марії Іванівни. Email support не є умовою цього тестового випуску; повна доставка листів не заявляється.

- Production project/site: dacha-annonce, https://dacha-annonce.web.app.
- Firestore Standard europe-west3, freeTier=true; billingEnabled=false перевірено перед deployment.
- Email/Password увімкнений; localhost та обидва Firebase Hosting domains у authorizedDomains.
- Єдиний адміністративний профіль MI створено за адресою, яку надав користувач. Пароль не встановлювався; MI використовує /reset-password, а потім /login. Листи агентом не надсилались.
- `firebase deploy --only firestore:rules,firestore:indexes --project dacha-annonce --non-interactive`: Deploy complete. Compiler прийняв Rules; залишив попередження статичного аналізу nullable map/unused helper argument, позитивні та негативні сценарії пройшли 25/25 у Emulator. Жодне попередження не приховано вимкненням перевірок.
- `flutter build web --release`: success; emulator flag не передавався.
- `firebase deploy --only hosting --project dacha-annonce --non-interactive --message "Dacha MI test release 2026-09-29"`: release complete, 39 файлів.
- Публічний main.dart.js збігається з локальною production-збіркою: SHA256 5d4b87c30f531dca5ddcf4acc4d304baefe8aa0aeb1e1f64e17a025b9deea0ee.
- HTTP 200 підтверджено для /, /reset-password, /admin. Фінальний Chrome smoke та READY indexes фіксуються нижче після перевірки.
- Реальні кімнати додає MI. Demo accounts/events/rooms не переносились. Commit/push не виконувалися.

Перший запуск MI: відкрити /reset-password → вказати власну адресу → встановити пароль із листа → /login → меню «Адміністрування» → «Кімнати» → «Додати кімнату». Після цього можна створити подію або перевірити заявку організатора.

Фінальний результат: усі 8 composite indexes — READY. scripts/hosting-smoke.mjs https://dacha-annonce.web.app — PASS: календар/порожній стан із production Firestore, deep-link 404, повернення, 320px, форма reset-password, жодних JS errors чи localhost emulator requests. Тестовий випуск доступний MI. Повний реальний login/password-reset лист перевіряє власниця адреси; чужу пошту або пароль агент не використовував.

## Оформлення Фонду — 2026-09-29

Опубліковано `Dacha Fund visual style 2026-09-29` на https://dacha-annonce.web.app. Джерело стилю: https://fond.boyarka.site/; основний зелений #36674D, біле тло, текст #666666, межі #D1D5DB, світлі поверхні #F0F5FA. Спільна Flutter-тема застосовується до календаря, форм та адміністративних сторінок.

Змінено: lib/app/app.dart, lib/app/presentation/shared.dart, lib/app/presentation/calendar_pages.dart, web/index.html, web/manifest.json і цей журнал.

Перевірки: dart format; flutter analyze без зауважень; 23 Flutter-тести успішні; release build успішний; Chrome desktop/mobile calendar/login без JS errors. Production hosting-smoke — PASS. Опублікований main.dart.js відповідає локальній збірці: SHA256 f28a1b623f52ff36ded3f6a76fb1287806910330ec0449648104c8b72a60e3e5. Опубліковано лише Hosting; commit/push не виконувалися.

## Розклад, локації та щотижневі події — 2026-09-30

Опубліковано `Dacha schedule locations and weekly events 2026-09-30` на https://dacha-annonce.web.app. Разом із Hosting опубліковано Firestore Rules: у заявки й публічні події додано `responsibleName`.

Зміни: форма місткості приймає порожнє поле й одне ціле 1–1000; інтерфейс називає кімнати локаціями; розклад має день, тиждень, місяць і список; картка локації відкриває її тиждень; MI створює щотижневі події як звичайні бронювання до 26 тижнів. П’ять локацій не записані в production: у базі кімнат немає, а місткість вітальні й додаткові простори ще не підтверджені. Листи Auth і пошта підтримки не змінювались і не позначені підключеними.

Перевірки: dart format; flutter analyze без зауважень; 32 Flutter-тести успішні; правила 25/25 у Emulator. Production hosting-smoke — PASS. Локальний main.dart.js SHA256 EAB14843EE2E0C26ED8BA518780D4F755649EEAF2C20544166DD364187765CF0. Commit/push не виконувалися.

## Навігація підтримки, фото й час на сьогодні — 2026-09-30

Опубліковано `Dacha support photos navigation and today end time 2026-09-30` на https://dacha-annonce.web.app разом із Firestore Rules для `supportTickets/.../attachments`.

- Кнопка «До списку звернень» на формі нового й на сторінці звернення.
- Фото JPEG/PNG/WebP до 700 КБ, до 5 на звернення, у Firestore без Cloud Storage/Blaze.
- Для події на сьогодні час підставляється на найближчий майбутній півгодинний слот; зрозумілі помилки про минулий початок.

Commit/push не виконувалися.

## Звернення MI: календар, видалення, організатори — 2026-10-14

Опубліковано Firestore Rules і Hosting release `MI calendar deletion and organizer permissions 2026-10-14` у проєкті `dacha-annonce`: https://dacha-annonce.web.app.

Сьогодні позначається колом, минулі дати/події приглушені. Додано видалення події й скінченної серії (із незмінною технічною історією), видалення архівної звільненої локації та дозвіл `canPublish`, який MI надає/відкликає окремому організатору. Організатор керує лише власними подіями. У профілі видно код акаунта для однозначної ідентифікації. Виправлено ширину фільтра ролей на 320 px. Інструкція: [mi-organizers-guide.md](mi-organizers-guide.md).

Перевірки: dart format; flutter analyze — без errors/warnings, два попередні info у support_draft_web.dart; 33 тести загального Flutter-набору та окремий новий тест надання/відкликання дозволу на 320 px успішні; 31 Rules-тест успішний. Наскрізний Flutter-клієнт у Chrome + Emulator перевірив публікацію, видалення серії, відсутність видалених заявок у списках, надання/відкликання дозволу й видалення локації. Звичайний production release build успішний. Емуляторна збірка не публікувалась.

Production HTTP 200: /, /reset-password, /admin. Опублікований main.dart.js збігається з локальним: SHA256 `c1cfada07041ab5c3a35369070a4a0f78d018b41962865565794f9e972dd0c0a`. Реальні події/локації/користувачі не створювались і не видалялись під час QA. Commit/push не виконувалися. Пошта потребує зовнішньої авторизації Apps Script і не позначена підключеною.

## Послідовні виправлення 15.10.2026

1. `DvjsCatpU4I9a2cEXRDh`: адміністратор відкриває керування з публічної картки минулої/сьогоднішньої події; адміністративний список починається з усіх статусів. Правила доступу не змінювались. 36 Flutter-тестів PASS; 32 Rules-тести PASS, включно з видаленням минулої події, звільненням часу та забороною сторонньому організатору. Analyze: 0 errors/warnings, 2 попередні info щодо dart:html. Hosting release `MI past event management 2026-10-15`, SHA256 main.dart.js `4892e7071b05ea16f44891287ccd69bf8efae63523fd2382b011e78a63416923` перевірено з production. Тікет done із коментарем.

2. `IudQNIep9DtPzfH9XyCH`: причина відмови видалення залишається в картці локації. 6 цільових Flutter-тестів PASS, включно зі збереженням помилки понад 10 секунд та повторною спробою. Hosting release `MI room deletion error visibility 2026-10-15`, SHA256 `ed3e92c07093107682eb638c52e6145cb08f096e972e044a159eece816e4f386` звірено з production. Тікет done із коментарем.

## Розклад за прикладами MI — 22.10.2026

Production dacha-annonce: опубліковано Firestore Rules, два індекси publicEvents/directions (обидва READY) та Hosting release «MI schedule table and directions 2026-10-22». main.dart.js SHA256: d280f77ec294398568a111a322240f85881c539835d956ad55ce6684f120ab1e; віддалена збірка точно збігається з локальною. /, /reset-password, /admin повертають HTTP 200. /schedule перевірено в браузері після deployment.

Перевірки: dart format без змін; 42 Flutter-тести PASS; 33 Rules-тести PASS, зокрема нові поля, підроблена публічна проєкція, заборонені ролі та перенесення між чотирма блоками. Наскрізний Flutter-сценарій у браузері на demo-dacha: PASS (booking, support, audit, roles). Production web build успішний. Analyze: 0 errors/warnings, 2 попередні info у support_draft_web.dart щодо dart:html. У Rules усунено повторні обчислення та кешовано проміжні значення, щоб вкладатися в ліміт 1000 expressions; обмеження доступу й атомарність збережено.

Вручну перевірено desktop-таблицю з реальною старою подією, мобільні картки 390 px, вибір дня через календар та фільтр напрямку на production-індексах. Нові поля перевірені на локальних тестових даних; реальні події не створювалися й не редагувалися під час QA. Знімок: .tools/oct22-published-schedule.png. Звернення WZsUavs1abnkzahWZvCk та Km67Ixi8IHsAomQb3kSn переведено в done з коментарями після deployment. Commit/push не виконувалися.
