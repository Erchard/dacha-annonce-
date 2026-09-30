# Безпека поточного стану

Production candidate Stage 2 відсутній. Кореневі Rules deny-all; experimental candidate знаходиться лише у rules-tests. Не копіювати його в deployment config до проходження gate (docs/stage2-gate.md).

У кандидата активний organizer може одинично get occupancy: тільки непрозорі booking IDs у слотах, без персональних даних. List доступний лише admin із limit<=100. Це навмисна прозорість зайнятості із SPEC §5.5; остаточна гарантія схеми ще потребує повного позитивного proof.

Users/bookings/history/adminAudit приватні. Developer не отримує прав MI. Self-registration не може встановлювати роль або isDisabled. Room/admin user mutations потребують атомарного append-only audit. Публічна проєкція має окремий allowlist. Support/mail paths закриті.

Тестові fixtures використовують mock auth contexts та emulator-only Admin bypass. Секрети й персональні production дані до тестів не додаються. Немає fallback з emulator на production. Дозволи UI ще не реалізовані і не заміняють Rules.
