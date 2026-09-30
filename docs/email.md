# Email-сповіщення підтримки

Стан на 2026-09-29: **blocked для фактичної доставки**. Звернення, коментарі та історія працюють незалежно від пошти. UI прямо повідомляє, що автоматичні сповіщення не підключені. Firebase Auth verification/reset — окремі штатні листи Firebase, вони не замінюють повідомлення підтримки.

Перевірені варіанти:

| Варіант | Що доступно | Чого бракує для цього проєкту |
|---|---|---|
| Resend Free | 3000 листів/місяць, до 100/день; API та idempotency key із вікном 24 години | Акаунт відправника, дозволений sender, API secret, адреса developer і trusted runtime |
| Brevo Free | До 300 листів/день, transactional email | Акаунт, підтверджений sender, API secret, адреса developer і trusted runtime |
| Cloudflare Workers Free + один із провайдерів | Trusted code й secret storage; до 100000 requests/день у межах обмежень Free | Окремий акаунт/runtime, налаштований доступ до Firebase та схема повторів/доставки |
| Cloud Functions for Firebase | Серверні Firestore triggers | Deployment потребує Blaze; суперечить поточній вимозі без billing |

Рішення: не додавати непідключений adapter, browser SMTP, відкритий relay або клієнтську чергу з довільним одержувачем. Без даних sender/recipient і доступного trusted runtime неможливо чесно підтвердити доставку. Акаунти, billing і domain автоматично не створювались. Вибір окремого runtime треба узгодити як реальну додаткову залежність; для малого застосунку це більше експлуатації, ніж решта поточного backend.

Для завершення потрібні підтверджений sender у вибраному провайдері, developer email і дозволений trusted runtime. Секрет налаштовується безпосередньо там, не в чаті/репозиторії/Flutter. Реалізація має читати незмінну history-подію, перевіряти actorRole=admin та created/commented, застосовувати fixed recipient, durable sent state за ticketId/version, retries із контрольованою невизначеною доставкою. Самого 24h idempotency Resend недостатньо для необмежених повторів. Після підключення обов’язкові реальні ticket/comment delivery, негативний developer-comment тест і повтор без дубля.

Повний MVP із email ще не завершений. Core release без автоматичної пошти потребує окремо прийнятого відхилення; воно не припускається мовчки.

Джерела, перевірено 2026-09-29:
- https://resend.com/pricing
- https://resend.com/docs/dashboard/emails/idempotency-keys
- https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- https://www.brevo.com/products/transactional-email/
- https://developers.cloudflare.com/workers/platform/limits/
- https://developers.cloudflare.com/workers/configuration/secrets/
- https://firebase.google.com/docs/functions/get-started
