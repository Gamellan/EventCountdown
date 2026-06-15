# Event Countdown

Event Countdown is a local-first Flutter app to track important dates like vacations, weddings, birthdays, and exams.

## Features

- Local event storage (no backend, no external data source)
- Event CRUD (create, edit, delete)
- Countdown labels: days left, today, or days ago
- Category support with visual markers
- Local reminders (none, same day, or 1 day before)
- Android home screen widget for nearest event
- Premium-inspired UI with clean cards and gradient background

## Tech Stack

- Flutter (Material 3)
- `shared_preferences` for offline persistence
- `home_widget` for Android widget integration
- `flutter_local_notifications` for offline reminders
- `intl` for date formatting
- `google_fonts` for typography

## Run

```bash
flutter pub get
flutter run
```

## Validate

```bash
flutter analyze
flutter test
```

## Android Widget

The app includes `EventCountdownWidgetProvider` and updates widget values from Flutter using `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget`.
