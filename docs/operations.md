# Операційні передумови

Перевірено 2026-09-28. Користувач налаштував Firebase project dacha-annonce через FlutterFire. 2026-09-28 read-only Cloud Billing API підтвердив billingEnabled=false. Region Firestore цим preview deployment не перевірявся. Звичайний запуск використовує dacha-annonce, явний emulator mode — лише demo-dacha. Billing не підключався.

| Сервіс Spark | Безоплатна квота / умова |
|---|---|
| Firestore Standard | 1 GiB даних, 50 000 reads / день, 20 000 writes / день, 20 000 deletes / день, 10 GiB egress / місяць |
| Static Hosting | 10 GB storage; pricing вказує 360 MB/day transfer, Hosting guide — 10 GB/month. Джерела розходяться: перед release звірити фактичну квоту в Console, не вважати ці значення двома незалежними квотами |
| Auth email/password | Без SMS; verification 1 000 листів / день, password reset 150 / день; додаткові anti-abuse limits |
| Cloud Storage | Потребує Blaze з 03.02.2026; у застосунку відсутній |

Джерела: [Firebase pricing](https://firebase.google.com/pricing), [Hosting quotas](https://firebase.google.com/docs/hosting/usage-quotas-pricing), [Auth limits](https://firebase.google.com/docs/auth/limits), [Storage changes](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

Spark не потребує платіжного методу. Не переходити на Blaze для обходу квот. При вичерпанні квоти зупинити зайві запити/listeners, повідомити про тимчасову недоступність і дочекатися відновлення квоти. Не видавати quota error за порожній календар. Квоти різних продуктів мають різні періоди відновлення; перевірити Usage у Console.

Identity Platform не активовано цим проєктом; для нього існують окремі DAU обмеження. Жодні email для support на Stage 1 не надсилаються. Backup/restore, retention та incident runbook доповнюються на відповідних Stage; поточний skeleton не зберігає прикладних даних.




## Робота власника

Перший MI/developer: створити звичайний акаунт і профіль через застосунок, підтвердити email; власник у Firebase Console → Firestore → users/{uid} змінює лише role на admin або developer. Перевірити UID за Auth, не за відображуваним ім’ям. Клієнт не має role editor. Після зміни — оновити сторінку; тестувати права у відповідному акаунті. Не використовувати локальні demo emails/passwords у production.

При вичерпанні квоти UI показує помилку. Перевірити Usage у Console, припинити зайві запити, дочекатися reset. Не підключати billing автоматично. Ліміти пагінації обмежують один запит, але не захищають від усіх форм зловживання публічним читанням.

При інциденті доступу: припинити проблемний клієнтський сценарій, перевірити роль/isDisabled та audit; виправити Rules із негативним тестом у Emulator. Не відкривати колекцію «тимчасово» для налагодження. Rollback Hosting не відновлює дані й не повертає Rules.

Backup/recovery: автоматичний backup не налаштований. Не вважати managed export/PITR безкоштовними. Власник може окремо підготувати локальний Admin SDK export у приватний файл поза Git у контрольоване вікно без записів; інструмент та credentials не входять до браузера. Перед production restore потрібна репетиція в Emulator: profiles/roles, rooms, booking history versions, відповідність occupancy slots і publicEvents, support/history/comments. JSON dump під час паралельних writes не є гарантовано узгодженим snapshot. Auth identities експортуються/відновлюються окремо від Firestore profiles. Неперевіреного restore script у проєкті немає.

Retention: автоматичного видалення заявок, подій і підтримки немає. Запити на очищення персональних даних обробляє власник із перевіркою пов’язаних documents; просте видалення booking залишило б locks/public/history у неконсистентному стані. Не обіцяти користувачам кнопки видалення акаунта, якої немає.

### Відома межа FlutterFire Auth Emulator

Release smoke перевіряє зміну екранів у застосунку й анонімні deep links. У firebase_auth_web 6.3.0 після повного reload release-сторінки емуляторна Auth session не відновлюється: plugin чекає initial Auth state до useAuthEmulator, а автоматичне відновлення emulator origin працює тільки для localhost у debug mode. Встановлений код і upstream issue: https://github.com/firebase/flutterfire/issues/10200. Production persistence цим emulator-тестом не доведена; її треба перевірити на реальному Firebase перед релізом. Для локальної щоденної роботи використовувати звичайний `flutter run -d chrome` з emulator flag (debug, localhost); після перезапуску самого Emulator увійти заново. SDK не патчиться, demo token не переноситься в production, повторний login не приховується автоматичним fallback.
