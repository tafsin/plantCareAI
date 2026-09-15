# Reminder scenario verification — 2026-09-15

Environment:

- Flutter debug builds on the ARM64 Android emulator (`qemu-system-aarch64`) and Chrome web.
- Real Firebase project `plantcare-ai-dev-tasnimalam` and the requested existing Firebase user.
- Firebase emulator flags were not supplied. App Check and its debug provider were not enabled.
- Flutter UI interaction and visual inspection used Marionette MCP.

## Results

| Scenario | Result | Evidence |
| --- | --- | --- |
| Create a manual care reminder | Pass | `01-create-reminder-form.png`, `03-denied-reminder-still-saved.png`, `firestore-reminders-proof.json` |
| Grant notification permission | Pass | `02-notification-permission-prompt.png`, `android-notification-permission.txt`, `android-device-timezone.txt`, `android-alarm-after-restart.txt`, `firestore-reminders-proof.json` |
| Deny notification permission | Pass | `02-notification-permission-prompt.png`, `03-denied-reminder-still-saved.png`, `04-denied-active-retry-details.png` |
| Open a delivered notification | Pass | `08-delivered-system-notification.png`, `09-notification-opens-protected-route.png`, `scheduled_notifications.xml` |
| Complete a reminder | Pass | `05-status-completed.png`, `07-reconciled-after-restart.png` |
| Cancel a reminder | Pass | `06-status-cancelled.png`, `07-reconciled-after-restart.png` |
| Reconcile after restart | Pass | `07-reconciled-after-restart.png`, `android-alarm-after-restart.txt`, `scheduled_notifications.xml` |
| Explain web reminder limitations | Pass | `10-web-reminder-limitations.png` |

## Runtime details

- The saved reminder path is owner-scoped as shown in `firestore-reminders-proof.json`.
- The displayed Android local time `2026-09-16 14:08:10.123631` is stored by Firestore as the UTC timestamp `2026-09-16T18:08:10.123631Z`.
- Android reported device timezone `America/Toronto`.
- The scheduled-notification cache contains deterministic notification ID `1201927568`, timezone `America/Toronto`, and protected payload `/plants/eGUh6GIJ1w3agL1P1w1m/reminders/P4JuHz2X104ICgrps3Lf`.
- After restart, Android's alarm table contained one PlantCare `ScheduledNotificationReceiver` alarm for the one future active reminder; completed and cancelled reminders appeared only in history.
- To exercise actual delivery without waiting until the next day, the emulator clock was advanced through Android's alarm service past the inexact alarm window. The operating system delivered the scheduled notification through the plugin receiver. After the notification was tapped and the route verified, the emulator clock was restored to host time and automatic time was re-enabled.
