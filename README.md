# Gymnastics Judging Expense Tracker

A cross-platform mobile application for gymnastics meet managers to track and manage expenses for gymnastics meets.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── judge.dart
│   ├── event.dart
│   └── expense.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── judges/
│   │   └── judges_list_screen.dart
│   ├── events/
│   │   ├── events_list_screen.dart
│   │   └── event_detail_screen.dart
│   └── settings/
│       └── settings_screen.dart
├── services/                 # Business logic & database
│   └── database_service.dart
├── providers/                # State management (Riverpod)
└── widgets/                  # Reusable components
```

## Getting Started

### Prerequisites

1. **Install Flutter**: See [FLUTTER_SETUP.md](FLUTTER_SETUP.md) for installation instructions
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

### Generate JSON Serialization Code

The app uses `json_serializable` for model serialization. Generate the required code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run the App

```bash
# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on Chrome (for testing)
flutter run -d chrome
```

## Development Roadmap

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the complete project plan.

### Phase 1: Foundation (Current)
- ✅ Project structure created
- ✅ Database schema defined
- ✅ Core models created
- ✅ Basic navigation setup
- 🔄 Judge CRUD operations (Next)

### Phase 2: Core Features
- Event creation and management
- Session/floor structure
- Judge assignment interface

### Phase 3: Expenses
- Expense tracking with all categories
- Auto-calculations
- Receipt photo handling

### Phase 4: Reports & Export
- PDF generation
- CSV export
- Judge import/export

## Features

- **Local-First Architecture**: All data stored locally, no internet required
- **Judge Database**: Manage judges with hourly rates and assignments
- **Event Management**: Create multi-day events with sessions and floors
- **Expense Tracking**: Comprehensive expense categories including mileage, meals, lodging, etc.
- **Auto-Calculations**: Automatic fee calculation based on hourly rates and session duration
- **Reports**: Generate professional PDF reports for reimbursement
- **Import/Export**: Share judge lists between users

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Local Database**: SQLite (sqflite)
- **Navigation**: GoRouter
- **PDF Generation**: pdf package
- **File Handling**: file_picker, share_plus

## License

Private project - All rights reserved
