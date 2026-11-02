# Самостійне безкоштовне розгортання «Дача-Анонс» на вашому Google-акаунті

**Для кого цей файл**

1. Людина, яка хоче **свою** копію сайту «Дача» (календар / бронювання) **безкоштовно** на Firebase.  
2. **Нейромережа** (Google AI Studio, Cursor, Codex тощо), якій людина **віддає цей документ цілком** і каже: «зроби / проведи мене».

Читати все самому не обов’язково: відкрийте https://aistudio.google.com/apps (або чат у AI Studio), вставте **весь цей файл** і короткий запит з розділу «Старт для людини» нижче.

**Що вийде в кінці:** ваш сайт на кшталт `https://ВАШ-PROJECT-ID.web.app`, окремий від публічного прикладу https://dacha-annonce.web.app  

**Код:** https://github.com/Erchard/dacha-annonce_  

---

## Старт для людини (скопіюйте в AI Studio)

Відкрийте https://aistudio.google.com/apps → новий чат / застосунок → вставте **весь цей markdown** і додайте:

```text
Ти — технічний асистент. Прочитай документ повністю.
Мета: безкоштовно розгорнути клон сайту «Дача-Анонс» на МОЄМУ Google-акаунті (Firebase Spark).
Працюй покроково: одна фаза → чекай моєї відповіді «готово» або скрін/текст помилки → наступна фаза.
Не вмикай платний Blaze. Не проси service account JSON у чат.
Команди давай готові для Windows PowerShell, коли я на Windows (або запитай мою ОС).
Починай з Фази 0: перевірки середовища.
```

Далі просто відповідайте асистенту: «готово», вставляйте вивід терміналу або опис помилки.

---

## Інструкція для нейромережі (системна роль)

Ти ведеш користувача-новачка до робочого **власного** клону проєкту Flutter Web + Firebase Auth + Firestore + Hosting.

### Жорсткі правила

1. **Лише Spark (безкоштовно).** Не пропонуй Blaze, Cloud Functions, Cloud Storage «для зручності». У цьому MVP Storage і Functions немає.  
2. **Не змішуй** чужий production `dacha-annonce` з проєктом користувача. Після клону обов’язковий `flutterfire configure --project=ЙОГО_ID`.  
3. **Секрети:** не проси паролі користувачів сайту, service account keys, OAuth refresh tokens у чат. Web `apiKey` у `firebase_options.dart` — публічний клієнтський конфіг, його можна обговорювати.  
4. **Seed** (`npm … run seed`) — **тільки** з емуляторами й `demo-dacha`. Ніколи на живий Firebase користувача.  
5. Після кожної фази: коротко «що зробили → що перевірити → команда / клік наступної фази». Не вивалюй усі фази одразу.  
6. Мова відповідей користувачу: **українська**, просто.  
7. Якщо користувач у Google AI Studio **без** доступу до його диска/терміналу — ти лише диктуєш кроки; він копіює команди локально. Якщо є агент з терміналом (Cursor) — можеш пропонувати виконувати команди самому, але з підтвердженням на `firebase deploy` і зміну ролей у Console.

### Стек (факти)

| Шар | Технологія |
|-----|------------|
| UI | Flutter Web |
| Auth | Firebase Email/Password |
| БД | Cloud Firestore + `firestore.rules` + `firestore.indexes.json` |
| Сайт | Firebase Hosting зі `build/web` |
| Backend Node у проді | немає |

Орієнтири версій: Flutter ≥ 3.47, Dart ≥ 3.13, Node 20/22, Firebase CLI свіжий. Деталі запуску емуляторів — у `README.md` репозиторію.

---

## Фаза 0 — Середовище на ПК

**Мета:** інструменти встановлені.

Користувач ставить (якщо ще немає):

- Git  
- Flutter (stable) + `flutter doctor` (Chrome OK)  
- Node.js LTS  
- Java (для локального Firestore Emulator, пізніше)  
- Chrome  
- `npm install -g firebase-tools` → `firebase login` (той самий Google, де буде проєкт)

Перевірка:

```powershell
git --version
flutter --version
node --version
firebase --version
```

Критерій готовності: усі команди щось виводять без «не розпізнано».

---

## Фаза 1 — Код з GitHub

```powershell
cd D:\Projects
git clone https://github.com/Erchard/dacha-annonce-.git
cd dacha-annonce-
flutter pub get
npm.cmd ci
npm.cmd --prefix rules-tests ci
```

Порада: краще **Fork** на GitHub користувача, потім клонувати форк — зручніше пушити свої зміни.

Критерій: папка відкривається, `flutter pub get` без фатальних помилок.

---

## Фаза 2 — Свій Firebase Spark

У https://console.firebase.google.com/ :

1. **Create project** (назва довільна; запам’ятати **Project ID**).  
2. Analytics — за бажанням вимкнути.  
3. **Не** вмикати Blaze.  
4. **Authentication** → Sign-in method → **Email/Password** → Enable.  
5. **Firestore** → Create database → production mode → регіон бажано `europe-west3` (обрати раз і назавжди).  
6. **Hosting** → Get started (файли замінить deploy).

Критерій: у Console видно Auth, Firestore, Hosting; відомий Project ID.

---

## Фаза 3 — Прив’язати Flutter до ЙОГО проєкту

У клоні зараз чужий `lib/firebase_options.dart` (`dacha-annonce`). Його треба замінити.

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=ВАШ-PROJECT-ID
```

Обрати Web. Перевірити в `lib/firebase_options.dart`, що `projectId` = проєкт користувача.

Критерій: у файлі немає `dacha-annonce` як projectId (або користувач свідомо підтвердив свій ID).

---

## Фаза 4 — Rules і індекси

```powershell
firebase deploy --only firestore:rules,firestore:indexes --project ВАШ-PROJECT-ID
```

Firestore → **Indexes** → дочекатися **Enabled/Ready**.

Критерій: deploy successful; індекси Ready.

---

## Фаза 5 — Збірка і Hosting

```powershell
flutter build web --release
firebase deploy --only hosting --project ВАШ-PROJECT-ID --message "Перший реліз"
```

**Заборонено** деплоїти збірку з `--dart-define=USE_FIREBASE_EMULATORS=true`.

Auth → Settings → **Authorized domains**: додати `ВАШ-PROJECT-ID.web.app` і `….firebaseapp.com` (+ `localhost` за потреби).

Критерій: відкривається `https://ВАШ-PROJECT-ID.web.app`.

---

## Фаза 6 — Перший адміністратор

1. На сайті → реєстрація → підтвердження email (якщо лист дійшов; інакше — спам / очікування; не вигадувати «пошту зламано в коді» без перевірки).  
2. Firestore: знайти профіль користувача (див. `docs/data-model.md`, колекція профілів / UID).  
3. Виставити роль **admin** (і не `isDisabled`), згідно з моделлю в репо.  
4. Перелогінитись.

Клієнт **не** може сам призначити admin — лише Console / Admin API власника.

Критерій: видно адмін-меню (керування подіями / локації / користувачі тощо).

---

## Фаза 7 — Безпечна щоденна розробка (емулятори)

Термінал 1:

```powershell
npx.cmd --no-install firebase emulators:start --only auth,firestore --project demo-dacha
```

Термінал 2:

```powershell
$env:GCLOUD_PROJECT='demo-dacha'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
npm.cmd --prefix rules-tests run seed
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Демо-акаунти — лише з README; лише емулятор.

Перед релізом змін:

```powershell
flutter analyze
flutter test
```

Оновлення продакшену після фіч:

```powershell
flutter build web --release
firebase deploy --only hosting --project ВАШ-PROJECT-ID
```

(Rules/indexes — лише якщо їх змінювали.)

---

## Фаза 8 — Далі розвивати з AI (AI Studio, Cursor, Codex)

### Якщо користувач лишається в Google AI Studio

- Нові фічі: вставляти скріни / текст тікета + цей документ + «змінюй лише потрібні файли, покажи diff словами, я внесу локально».  
- AI Studio часто **не** пише прямо на диск — тоді асистент генерує патчі/команди, людина виконує.

### Якщо є Cursor / Codex на клоні

Користувач відкриває папку репо і пише агенту, наприклад:

```text
Працюємо в клоні Дача-Анонс. Документ docs/junior-self-host-guide.md уже виконаний для мого Firebase.
Задача: …
Не вмикай Blaze. Не seed у production. Analyze після змін. Deploy тільки якщо я скажу.
```

Давати агенту якірні файли: `README.md`, `SPEC.md`, `docs/data-model.md`, `docs/email.md`, `firestore.rules`.

### Чого AI не обіцяти

- Гарантовану доставку листів Firebase Auth / окрему пошту тікетів без службового SMTP (`docs/email.md`).  
- «Безкоштовні» Cloud Functions / Storage у обхід політики Google.

---

## Швидкий чеклист готовності

- [ ] Клон/форк на ПК  
- [ ] Свій Spark-проєкт, Auth + Firestore + Hosting  
- [ ] Свій `firebase_options.dart`  
- [ ] Deploy rules + indexes (Ready)  
- [ ] Deploy hosting, сайт відкривається  
- [ ] Authorized domains  
- [ ] Перший admin у Firestore  
- [ ] Зрозуміло, як ганяти емулятори  

---

## Типові збої → підказка асистенту

| Симптом | Дія |
|---------|-----|
| permission-denied | Rules задеплоєні? Роль admin? |
| дивні порожні списки з фільтром | Indexes Ready? |
| старий UI після deploy | Hard refresh; правильний projectId |
| лист не прийшов | Spam; шаблон Auth; не ламати продукт «фальшивою поштою» |
| seed «все стерло» | Перевірити, що це був лише emulator |

---

## Корисні посилання репозиторію

| Файл | Навіщо |
|------|--------|
| `README.md` | Локальний запуск і тести |
| `docs/deployment.md` | Досвід релізів |
| `docs/operations.md` | Квоти Spark |
| `docs/data-model.md` | Структура даних і ролі |
| `docs/email.md` | Межі пошти |

---

*Кінець документа. Нейромереже: починай з Фази 0 і чекай відповіді користувача.*
