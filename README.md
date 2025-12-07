# Gymnastics Meet Expenses

A comprehensive expense tracking solution designed specifically for gymnastics meet managers, judges, and event coordinators.

## Download

Coming soon to the [App Store](https://apps.apple.com)

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

### 📊 Comprehensive Expense Tracking
- Track all meet-related expenses with detailed categorization
- Record mileage, per diem, hotel, and miscellaneous costs
- Attach receipts and notes to individual expenses
- Monitor spending across multiple events and associations

### 📄 Professional Invoicing
- Generate detailed PDF invoices with itemized expenses
- Include session details, dates, times, and floor assignments
- Automatic calculations with subtotals and grand totals
- Share invoices via email or save to Files

### 📅 Multi-Event Management
- Organize expenses by event, association, and date
- Create custom event structures with days, sessions, and floors
- Track expenses across unlimited events

### 👥 Judge Assignment Tools
- Manage judge assignments for complex meet structures
- Support for multiple sessions, rotations, and apparatus
- Visual event structure overview

### 📈 Powerful Reporting
- Combined event reports with full expense breakdowns
- Judge assignment summaries by floor and session
- Export all reports as professional PDFs

### 🔒 Privacy & Security
- All data stored locally on your device
- No account required
- Your financial information stays private
- Optional iCloud backup

## Platform Support

- ✅ iOS 13.0+
- ✅ iPad & iPhone optimized
- ✅ Portrait and landscape orientations

## Technology Stack

- **Framework**: Flutter 3.38.4
- **State Management**: Riverpod
- **Local Database**: Hive
- **Routing**: Go Router
- **PDF Generation**: pdf package
- **Charts**: FL Chart

## Support

For questions, bug reports, or feature requests:
- 📧 Email: support@gymnasticsmeetexpenses.app
- 🌐 Website: [GitHub Pages](https://derekwalsh1.github.io/gymnastics-meet-expenses/)

## Privacy

Gymnastics Meet Expenses respects your privacy:
- No data collection or tracking
- All data stored locally on your device
- No account required
- No third-party analytics or ads

## License

Copyright © 2025 Derek Walsh. All rights reserved.

Private project - All rights reserved
