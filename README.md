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

## Recent Updates (v1.1.1)

### 🎨 Visual Enhancements
- **Floor Color Customization**: Assign colors to floors for easy visual identification (blue, green, white, black, pink, yellow, orange, lavender, beige)
- **Responsive Design**: Fixed text clipping on small screens across all views
- **Streamlined Navigation**: Import and create buttons consolidated in Events screen

### 🌍 International Support
- Country selector in event creation with dynamic field labels
- Support for international addresses (State/Province, Zip/Postal Code)
- Default to United States with 9 country options

### ⚡ Performance & Testing
- Comprehensive integration tests for complete app flow
- Optimized test performance (60% faster execution)
- Enhanced error handling and user feedback

### 📊 Data Management
- Floor colors preserved in meet import/export
- Improved CSV exports (streamlined columns)
- Optional descriptions for role-based fees

## Development Status

✅ **Production Ready** - All core features implemented and tested

### Completed Features
- ✅ Complete judge management with multiple certification levels
- ✅ Event creation with multi-day, multi-session, multi-floor structures
- ✅ Judge assignment with apparatus-specific tracking
- ✅ Comprehensive expense tracking (6 categories)
- ✅ Fee management (session rates, hourly rates, role-based bonuses)
- ✅ PDF invoice and report generation
- ✅ CSV export functionality
- ✅ Meet import/export for backup and transfer
- ✅ Event structure cloning
- ✅ Visual analytics (pie charts, bar charts)
- ✅ Responsive UI for all screen sizes
- ✅ Integration testing suite

## Features

### 📊 Comprehensive Expense Tracking
- Track all meet-related expenses with detailed categorization (Mileage, Airfare, Parking, Meals & Per Diem, Lodging, Other)
- Record expenses by judge and automatically categorize
- Monitor spending across multiple events and associations
- Track both reimbursable expenses and taxable fees

### 📄 Professional Invoicing & Reports
- Generate detailed PDF invoices with itemized expenses and fees
- Include session details, dates, times, and floor assignments
- Automatic calculations with subtotals and grand totals (fees for 1099s, reimbursable expenses, total payout)
- Share invoices via email, save to Files, or print directly
- Financial reports with visual analytics (pie charts, bar charts)
- Export data to CSV for external processing

### 📅 Multi-Event Management
- Organize expenses by event, association, and date
- Create custom event structures with days, sessions, and floors
- **Visual floor identification with customizable colors** (9 color options)
- Track expenses across unlimited events
- Import/Export complete meets for backup or transfer
- Clone event structures to quickly set up similar meets
- International address support with dynamic field labels

### 👥 Judge Management & Assignment
- Maintain judge database with multiple certification levels per judge
- Manage judge assignments for complex meet structures
- Support for multiple sessions, rotations, and apparatus-specific assignments
- Assign judges to specific floors with visual color coding
- Track hourly rates, session fees, and role-based bonuses (Meet Referee, Head Judge)
- Multi-select functionality for bulk judge operations
- Visual event structure overview with fee calculations

### 📈 Powerful Reporting & Analytics
- Combined event reports with full expense breakdowns by judge
- Visual expense distribution with interactive pie charts
- Judge earnings comparison with bar charts
- Session and floor fee summaries
- Export comprehensive financial reports as PDF or CSV

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

- **Framework**: Flutter 3.24+
- **State Management**: Riverpod 2.6.1
- **Local Database**: SQLite (sqflite)
- **Routing**: Go Router 17.0.0
- **PDF Generation**: printing 5.14.2, pdf 3.12.0
- **Charts**: fl_chart 0.70.2
- **File Handling**: file_picker 10.3.7, share_plus 12.0.1
- **JSON Serialization**: json_serializable 6.9.4
- **Image Handling**: image_picker 1.2.0

## Support

For questions, bug reports, or feature requests:
- 📧 Email: derek.walsh@gmail.com
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
