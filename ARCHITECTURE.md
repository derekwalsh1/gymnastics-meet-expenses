# Application Architecture Documentation

**Project:** NAWGJ Expense Tracker  
**Platform:** Flutter (iOS & Android)  
**Version:** 1.0.0+10  
**Last Updated:** December 11, 2025

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Pattern](#architecture-pattern)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Data Layer](#data-layer)
6. [Business Logic Layer](#business-logic-layer)
7. [Presentation Layer](#presentation-layer)
8. [Key Features](#key-features)
9. [Database Schema](#database-schema)
10. [State Management](#state-management)
11. [Navigation](#navigation)
12. [Import/Export System](#importexport-system)
13. [PDF & Reporting](#pdf--reporting)
14. [Development Workflow](#development-workflow)

---

## Project Overview

The **Gymnastics Judging Expense Tracker** is a comprehensive expense management solution designed for gymnastics meet managers to track judge assignments, expenses, and generate professional reports for event organizers.

### Core Purpose
Enable meet managers to:
- Manage a database of judges with certifications across multiple associations
- Create and organize gymnastics meet events with hierarchical structure (Days → Sessions → Floors)
- Assign judges to specific floor assignments
- Track all meet-related expenses (mileage, per diem, hotel, miscellaneous)
- Generate professional PDF reports and CSV exports for reimbursement

### Key Characteristics
- **Local-first architecture**: All data stored on device using SQLite
- **Offline-capable**: Full functionality without internet connection
- **Import/Export system**: Share judge lists and meet data between users
- **Cross-platform**: Single codebase for iOS and Android

---

## Architecture Pattern

The application follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│         Presentation Layer (UI)              │
│    Screens, Widgets, GoRouter Navigation    │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│      State Management (Riverpod)             │
│         Providers (FutureProvider,           │
│      StateNotifierProvider, Provider)        │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│       Business Logic Layer                   │
│     Repositories (Data Operations)           │
│     Services (Import/Export, PDF, CSV)       │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│           Data Layer                         │
│    DatabaseService (SQLite/Sqflite)          │
│         Models (JSON Serializable)           │
└─────────────────────────────────────────────┘
```

### Design Principles

1. **Single Responsibility**: Each class/file has one clear purpose
2. **Dependency Injection**: Riverpod providers manage dependencies
3. **Immutability**: Models are immutable with `copyWith()` methods
4. **Type Safety**: Strong typing with null-safety enabled
5. **Repository Pattern**: Data access abstracted through repositories
6. **Reactive Programming**: UI updates reactively to state changes

---

## Technology Stack

### Core Framework
- **Flutter SDK**: 3.2.0+
- **Dart**: Null-safe Dart 3.2.0+

### State Management
- **flutter_riverpod** (2.4.9): Reactive state management
  - Provides dependency injection
  - Caching and lifecycle management
  - Compile-time safe providers

### Local Storage
- **sqflite** (2.3.0): SQLite database for Flutter
- **path_provider** (2.1.1): File system location access
- **path** (1.8.3): Path manipulation utilities

### Navigation
- **go_router** (17.0.0): Declarative routing
  - Type-safe routes
  - Deep linking support
  - Named routes

### UI & Theming
- **Material Design 3**: Modern UI components
- **google_fonts** (6.1.0): Custom typography
- **cupertino_icons** (1.0.6): iOS-style icons

### File Operations
- **file_picker** (10.0.0): File selection from device
- **share_plus** (12.0.1): Native share dialogs
- **image_picker** (1.1.0): Camera and gallery access for receipts

### Document Generation
- **pdf** (3.10.7): PDF document creation
- **printing** (5.13.0): Print and share PDFs
- **csv** (6.0.0): CSV file generation

### Data Visualization
- **fl_chart** (1.1.1): Beautiful charts and graphs

### Utilities
- **intl** (0.20.2): Internationalization and date/time formatting
- **uuid** (4.2.2): Unique identifier generation
- **json_annotation** (4.8.1): JSON serialization annotations
- **async** (2.11.0): Async utility functions

### Development Tools
- **build_runner** (2.4.7): Code generation
- **json_serializable** (6.7.1): JSON serialization code gen
- **flutter_lints** (6.0.0): Recommended linting rules
- **flutter_launcher_icons** (0.14.1): App icon generation

---

## Project Structure

```
lib/
├── main.dart                      # App entry point, routing config
├── models/                        # Data models (immutable DTOs)
│   ├── judge.dart                 # Judge entity
│   ├── judge_level.dart           # Judge certification level
│   ├── judge_certification.dart   # Judge-to-level junction
│   ├── judge_fee.dart             # Fee structure by level
│   ├── judge_with_level.dart      # Composite model with certifications
│   ├── event.dart                 # Event/meet entity
│   ├── event_day.dart             # Day within an event
│   ├── event_session.dart         # Session within a day
│   ├── event_floor.dart           # Floor/apparatus within session
│   ├── event_template.dart        # Reusable event structure
│   ├── event_with_structure.dart  # Composite event with hierarchy
│   ├── judge_assignment.dart      # Judge assigned to floor
│   ├── expense.dart               # Expense entry
│   ├── event_report.dart          # Generated report metadata
│   ├── meet_import_export_result.dart  # Import/export results
│   └── *.g.dart                   # Generated serialization code
│
├── repositories/                  # Data access layer
│   ├── judge_repository.dart      # Judge CRUD operations
│   ├── judge_level_repository.dart
│   ├── judge_certification_repository.dart
│   ├── judge_fee_repository.dart
│   ├── event_repository.dart      # Event CRUD operations
│   ├── event_day_repository.dart
│   ├── event_session_repository.dart
│   ├── event_floor_repository.dart
│   ├── judge_assignment_repository.dart
│   ├── expense_repository.dart
│   └── report_repository.dart
│
├── providers/                     # Riverpod state providers
│   ├── judge_provider.dart        # Judge state & filters
│   ├── judge_level_provider.dart
│   ├── judge_certification_provider.dart
│   ├── judge_fee_provider.dart
│   ├── event_provider.dart        # Event state & filters
│   ├── judge_assignment_provider.dart
│   ├── expense_provider.dart
│   └── report_provider.dart
│
├── services/                      # Business logic services
│   ├── database_service.dart      # SQLite setup & migrations
│   ├── judge_import_export_service.dart
│   ├── judge_level_import_export_service.dart
│   ├── meet_import_export_service.dart
│   ├── pdf_service.dart           # PDF generation
│   └── csv_service.dart           # CSV export
│
├── screens/                       # UI screens (pages)
│   ├── home_screen.dart           # Dashboard/landing
│   ├── import_meet_screen.dart    # Meet import wizard
│   │
│   ├── judges/                    # Judge management screens
│   │   ├── judges_list_screen.dart
│   │   ├── judge_import_export_screen.dart
│   │   ├── judge_level_import_export_screen.dart
│   │   ├── associations_screen.dart
│   │   ├── judge_levels_screen.dart
│   │   └── add_edit_judge_level_screen.dart
│   │
│   ├── events/                    # Event management screens
│   │   ├── events_list_screen.dart
│   │   ├── create_event_wizard_screen.dart
│   │   ├── event_detail_screen.dart
│   │   ├── event_structure_screen.dart
│   │   ├── event_day_detail_screen.dart
│   │   ├── event_session_detail_screen.dart
│   │   ├── event_expenses_screen.dart
│   │   ├── edit_event_screen.dart
│   │   ├── assign_judge_screen.dart
│   │   ├── edit_assignment_screen.dart
│   │   ├── add_event_day_screen.dart
│   │   ├── add_event_session_screen.dart
│   │   └── add_event_floor_screen.dart
│   │
│   ├── meets/                     # Meet import/export
│   │   ├── meet_export_screen.dart
│   │   └── meet_import_screen.dart
│   │
│   ├── fees/                      # Fee management
│   │   └── manage_fees_screen.dart
│   │
│   ├── expenses/                  # Expense tracking
│   │   ├── expense_list_screen.dart
│   │   ├── add_edit_expense_screen.dart
│   │   └── expense_detail_screen.dart
│   │
│   ├── reports/                   # Report generation
│   │   ├── reports_list_screen.dart
│   │   └── event_report_detail_screen.dart
│   │
│   └── settings/
│       └── settings_screen.dart
│
└── widgets/                       # Reusable UI components
    └── (shared widgets)
```

---

## Data Layer

### Models

All models are **immutable** and use **json_serializable** for serialization:

```dart
@JsonSerializable()
class Judge {
  final String id;              // UUID
  final String firstName;
  final String lastName;
  final String? notes;
  final String? contactInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;        // Soft delete
  
  // JSON serialization
  factory Judge.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  
  // Database mapping
  factory Judge.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  
  // Immutable updates
  Judge copyWith({...});
  
  // Computed properties
  String get fullName => '$firstName $lastName';
}
```

### Key Model Relationships

```
Judge (1) ←→ (N) JudgeCertification (N) ←→ (1) JudgeLevel
  │
  └──→ (N) JudgeAssignment (N) ←──→ (1) EventFloor
                                         │
Event (1) ←→ (N) EventDay              │
                  │                      │
                  └──→ (N) EventSession ─┘
                             │
                             └──→ (N) Expense
```

### Composite Models

For efficient querying, composite models join related data:

- **JudgeWithLevels**: Judge + all certifications + levels
- **EventWithStructure**: Event + days + sessions + floors + assignments

### Database Service

**DatabaseService** is a singleton managing the SQLite database:

```dart
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nawgj_expense_tracker.db');
    return _database!;
  }
  
  // Handles migrations through version tracking
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion);
}
```

**Current Database Version**: 4

---

## Business Logic Layer

### Repository Pattern

Each entity has a dedicated repository handling CRUD operations:

```dart
class JudgeRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  
  Future<Judge> createJudge(Judge judge);
  Future<List<Judge>> getAllJudges({bool includeArchived = false});
  Future<Judge?> getJudgeById(String id);
  Future<int> updateJudge(Judge judge);
  Future<int> deleteJudge(String id);
  Future<int> archiveJudge(String id);
  
  // Complex queries
  Future<List<JudgeWithLevels>> getJudgesWithLevels();
  Future<JudgeWithLevels?> getJudgeWithLevels(String judgeId);
}
```

#### Clone Operations

Repositories support cloning entire structures:

```dart
// Clone a day with all sessions, floors, and assignments
EventDayRepository.cloneEventDay({
  required String eventDayId,
  required DateTime newDate,
  bool includeJudgeAssignments = true,
});

// Clone a session with all floors and assignments
EventSessionRepository.cloneEventSession({
  required String eventSessionId,
  String? newEventDayId,  // Optional: clone to different day
  bool includeJudgeAssignments = true,
});

// Clone a floor with its assignment
EventFloorRepository.cloneEventFloor({
  required String eventFloorId,
  String? newEventSessionId,  // Optional: clone to different session
  bool includeJudgeAssignments = true,
});

// Clone a judge assignment to another floor
JudgeAssignmentRepository.cloneAssignment({
  required String assignmentId,
  required String newEventFloorId,
});
```

**Clone Behavior:**
- Creates new UUIDs for all cloned entities
- Increments sequence numbers (day, session, floor numbers)
- Preserves relationships (sessions → floors → assignments)
- Optionally includes or excludes judge assignments
- Adds "(cloned)" notation to notes for tracking
```

**Benefits:**
- Single source of truth for data operations
- Testable in isolation
- Centralized error handling
- Query optimization

### Services

Services handle complex business logic:

#### Import/Export Services
- **JudgeImportExportService**: Import/export judge lists (JSON)
- **JudgeLevelImportExportService**: Import/export certification levels
- **MeetImportExportService**: Import/export complete meet structures

#### Document Services
- **PdfService**: Generate PDF expense reports with formatting
- **CsvService**: Export data to CSV format

---

## Presentation Layer

### Screens

Screens are organized by feature:
- **Home**: Dashboard with quick actions
- **Judges**: Judge database management
- **Events**: Meet creation, structure, assignments
- **Expenses**: Expense entry and tracking
- **Reports**: Report generation and history
- **Settings**: App configuration

### Widgets

Reusable components extract common UI patterns:
- Form fields
- List items
- Cards
- Dialogs
- Bottom sheets

---

## Key Features

### 1. Multi-Association Judge Management

Judges can hold **multiple certifications** across different associations:

```
Judge: Jane Smith
├── NAWGJ Level 8
├── NAWGJ Level 9
├── AAU Level 3
└── USAG Brevet
```

**Implementation:**
- Junction table `judge_certifications` enables many-to-many relationship
- Each certification tracks dates and expiration
- Filtering by association or specific level

### 2. Hierarchical Event Structure

Events have a **three-level hierarchy**:

```
Event: State Championship 2025
├── Day 1 (March 15)
│   ├── Morning Session (9:00 AM)
│   │   ├── Vault Floor (Judge: Jane Smith)
│   │   ├── Bars Floor (Judge: John Doe)
│   │   └── Beam Floor (Judge: Sarah Johnson)
│   └── Afternoon Session (2:00 PM)
│       └── ...
├── Day 2 (March 16)
│   └── ...
```

**Features:**
- Flexible structure (1-N days, sessions, floors)
- Assign judges to specific floors
- Track session times and details
- Calculate fees per assignment
- **Clone days, sessions, or floors** to quickly replicate structure and assignments

### 3. Judge Assignment System

Assigns judges to event floors with fee calculation:

```dart
class JudgeAssignment {
  final String id;
  final String eventFloorId;
  final String judgeId;
  final String? judgeLevelId;    // Certification used
  final double hourlyRate;        // Rate for this assignment
  final double hoursWorked;       // Actual hours
  final double calculatedFee;     // hourlyRate × hoursWorked
  final AssignmentStatus status;  // pending, confirmed, completed
}
```

**Features:**
- Pre-populate hourly rate from judge level
- Override rate per assignment
- Track assignment status
- Calculate total fees

### 4. Expense Tracking

Comprehensive expense categories:

- **Mileage**: Miles × rate
- **Per Diem**: Daily allowance
- **Hotel**: Accommodation costs
- **Meals**: Food expenses
- **Judging Fees**: Auto-calculated from assignments
- **Miscellaneous**: Other expenses

**Features:**
- Attach receipt photos
- Add notes per expense
- Link to specific event
- Calculate totals by category

### 5. Import/Export System

Share data between users:

**Judge Export:**
- Full list or filtered subset
- JSON format
- Share via email/AirDrop/files

**Judge Import:**
- Merge with existing judges
- Duplicate detection by name
- Update existing or skip

**Meet Import/Export:**
- Complete event structure
- Judge assignments
- Maintains relationships

### 6. Report Generation

Professional PDF reports for submission:

**Included:**
- Event details and schedule
- Judge assignments by session/floor
- Itemized expenses by category
- Mileage calculations
- Total reimbursement amount
- Receipt attachments

**Export Options:**
- PDF for printing/email
- CSV for spreadsheet import
- Share directly from app

---

## Database Schema

### Core Tables

#### judges
```sql
CREATE TABLE judges (
  id TEXT PRIMARY KEY,
  firstName TEXT NOT NULL,
  lastName TEXT NOT NULL,
  notes TEXT,
  contactInfo TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isArchived INTEGER NOT NULL DEFAULT 0
);
```

#### judge_levels
```sql
CREATE TABLE judge_levels (
  id TEXT PRIMARY KEY,
  association TEXT NOT NULL,          -- e.g., "NAWGJ", "AAU"
  level TEXT NOT NULL,                -- e.g., "Level 8", "Brevet"
  defaultHourlyRate REAL NOT NULL,
  sortOrder INTEGER NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  isArchived INTEGER NOT NULL DEFAULT 0
);
```

#### judge_certifications (Junction Table)
```sql
CREATE TABLE judge_certifications (
  id TEXT PRIMARY KEY,
  judgeId TEXT NOT NULL,
  judgeLevelId TEXT NOT NULL,
  certificationDate TEXT,
  expirationDate TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (judgeId) REFERENCES judges (id) ON DELETE CASCADE,
  FOREIGN KEY (judgeLevelId) REFERENCES judge_levels (id) ON DELETE CASCADE,
  UNIQUE(judgeId, judgeLevelId)
);
```

#### events
```sql
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  startDate TEXT NOT NULL,
  endDate TEXT NOT NULL,
  locationName TEXT NOT NULL,
  locationAddress TEXT,
  locationCity TEXT,
  locationState TEXT,
  description TEXT,
  totalBudget REAL,
  associationId TEXT,                 -- Optional association filter
  status TEXT NOT NULL,               -- draft, planned, active, completed
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
);
```

#### event_days
```sql
CREATE TABLE event_days (
  id TEXT PRIMARY KEY,
  eventId TEXT NOT NULL,
  dayNumber INTEGER NOT NULL,
  date TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventId) REFERENCES events (id) ON DELETE CASCADE
);
```

#### event_sessions
```sql
CREATE TABLE event_sessions (
  id TEXT PRIMARY KEY,
  eventDayId TEXT NOT NULL,
  sessionNumber INTEGER NOT NULL,
  name TEXT NOT NULL,               -- e.g., "Morning Session"
  startTime TEXT NOT NULL,
  endTime TEXT,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventDayId) REFERENCES event_days (id) ON DELETE CASCADE
);
```

#### event_floors
```sql
CREATE TABLE event_floors (
  id TEXT PRIMARY KEY,
  eventSessionId TEXT NOT NULL,
  floorNumber INTEGER NOT NULL,
  apparatus TEXT NOT NULL,          -- e.g., "Vault", "Bars", "Beam", "Floor"
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventSessionId) REFERENCES event_sessions (id) ON DELETE CASCADE
);
```

#### judge_assignments
```sql
CREATE TABLE judge_assignments (
  id TEXT PRIMARY KEY,
  eventFloorId TEXT NOT NULL,
  judgeId TEXT NOT NULL,
  judgeLevelId TEXT,                -- Which certification they're using
  hourlyRate REAL NOT NULL,
  hoursWorked REAL NOT NULL,
  calculatedFee REAL NOT NULL,
  status TEXT NOT NULL,             -- pending, confirmed, completed
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventFloorId) REFERENCES event_floors (id) ON DELETE CASCADE,
  FOREIGN KEY (judgeId) REFERENCES judges (id) ON DELETE CASCADE,
  FOREIGN KEY (judgeLevelId) REFERENCES judge_levels (id)
);
```

#### expenses
```sql
CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  eventId TEXT NOT NULL,
  category TEXT NOT NULL,           -- mileage, perDiem, hotel, meal, fee, misc
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  description TEXT,
  receiptPath TEXT,                 -- Local file path to receipt photo
  mileage REAL,                     -- For mileage category
  mileageRate REAL,                 -- $/mile
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventId) REFERENCES events (id) ON DELETE CASCADE
);
```

#### judge_fees (Fee Templates)
```sql
CREATE TABLE judge_fees (
  id TEXT PRIMARY KEY,
  judgeLevelId TEXT NOT NULL,
  feeType TEXT NOT NULL,            -- hourly, perSession, perDay, perEvent
  amount REAL NOT NULL,
  effectiveDate TEXT NOT NULL,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (judgeLevelId) REFERENCES judge_levels (id) ON DELETE CASCADE
);
```

### Indexes

Performance optimization:
```sql
CREATE INDEX idx_judge_levels_association ON judge_levels(association);
CREATE INDEX idx_judges_archived ON judges(isArchived);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_dates ON events(startDate, endDate);
CREATE INDEX idx_expenses_event ON expenses(eventId);
CREATE INDEX idx_assignments_floor ON judge_assignments(eventFloorId);
```

---

## State Management

### Riverpod Architecture

The app uses **Riverpod** for reactive state management:

#### Provider Types

1. **Provider**: Immutable dependencies (repositories, services)
```dart
final judgeRepositoryProvider = Provider<JudgeRepository>((ref) {
  return JudgeRepository();
});
```

2. **FutureProvider**: Async data fetching
```dart
final judgesWithLevelsProvider = FutureProvider<List<JudgeWithLevels>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  return repository.getJudgesWithLevels();
});
```

3. **StateProvider**: Simple mutable state
```dart
final judgeSearchQueryProvider = StateProvider<String>((ref) => '');
final judgeAssociationFilterProvider = StateProvider<String?>((ref) => null);
```

4. **StateNotifierProvider**: Complex state with logic
```dart
final eventWizardProvider = StateNotifierProvider<EventWizardNotifier, EventWizardState>(
  (ref) => EventWizardNotifier(),
);
```

### Reactive Updates

When data changes:
1. Repository performs database operation
2. Provider automatically invalidated
3. UI rebuilds with fresh data
4. No manual cache invalidation needed

```dart
// In UI
final judgesAsync = ref.watch(judgesWithLevelsProvider);

return judgesAsync.when(
  data: (judges) => JudgesList(judges: judges),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => ErrorWidget(err),
);
```

### Provider Composition

Providers can depend on other providers:

```dart
final filteredJudgesProvider = FutureProvider<List<JudgeWithLevels>>((ref) async {
  final allJudges = await ref.watch(judgesWithLevelsProvider.future);
  final searchQuery = ref.watch(judgeSearchQueryProvider);
  final associationFilter = ref.watch(judgeAssociationFilterProvider);
  
  // Apply filters
  return allJudges.where((judge) {
    if (searchQuery.isNotEmpty && !judge.matches(searchQuery)) return false;
    if (associationFilter != null && !judge.hasAssociation(associationFilter)) return false;
    return true;
  }).toList();
});
```

---

## Navigation

### GoRouter Configuration

Declarative routing with **go_router**:

```dart
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/judges',
      builder: (context, state) => const JudgesListScreen(),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) {
        final eventId = state.pathParameters['id']!;
        return EventDetailScreen(eventId: eventId);
      },
    ),
    // ... more routes
  ],
);
```

### Navigation Patterns

**Imperative:**
```dart
context.go('/judges');                    // Navigate and replace
context.push('/events/123');              // Navigate and push
context.pop();                            // Go back
```

**Deep Linking:**
- Routes support path parameters: `/events/:eventId/sessions/:sessionId`
- Query parameters: `/judges?association=NAWGJ&level=8`

---

## Import/Export System

### Judge Export

**Format:** JSON
```json
{
  "exportDate": "2025-03-15T10:30:00Z",
  "version": "1.0",
  "judges": [
    {
      "id": "uuid-123",
      "firstName": "Jane",
      "lastName": "Smith",
      "certifications": [
        {
          "association": "NAWGJ",
          "level": "Level 8",
          "certificationDate": "2023-01-15"
        }
      ],
      "contactInfo": "jane@example.com"
    }
  ]
}
```

**Process:**
1. Select judges (all or filtered)
2. Serialize to JSON
3. Write to file
4. Share via native share dialog

### Judge Import

**Duplicate Handling:**
- Match by `firstName + lastName`
- Options:
  - Skip existing
  - Update existing
  - Create duplicate with suffix

**Certification Merge:**
- Add new certifications to existing judges
- Avoid duplicate certifications

### Meet Import/Export

**Complete Structure:**
- Event details
- Days, sessions, floors
- Judge assignments (references judges by name)
- Expense templates

**Import Process:**
1. Parse JSON
2. Create/match judges
3. Create event structure
4. Link assignments

---

## PDF & Reporting

### PDF Generation

Using **pdf** package to create professional reports:

```dart
class PdfService {
  Future<Uint8List> generateEventReport(Event event) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildHeader(event),
        build: (context) => [
          _buildEventInfo(event),
          _buildSchedule(event),
          _buildExpenseSummary(event),
          _buildDetailedExpenses(event),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );
    
    return pdf.save();
  }
}
```

**Report Sections:**
1. **Header**: Event name, date, manager info
2. **Event Info**: Location, dates, description
3. **Schedule**: Days → Sessions → Floors with judge assignments
4. **Expense Summary**: Totals by category
5. **Detailed Expenses**: Line items with receipts
6. **Totals**: Grand total for reimbursement

### CSV Export

Simple tabular export:

```csv
Date,Category,Description,Amount,Judge,Notes
2025-03-15,Judging Fee,Jane Smith - Vault,150.00,Jane Smith,3 hours @ $50/hr
2025-03-15,Mileage,Round trip,45.60,N/A,80 miles @ $0.57/mile
```

---

## Development Workflow

### Code Generation

Models use code generation for JSON serialization:

```bash
# Generate once
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode during development
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Database Migrations

When updating schema:
1. Increment version in `DatabaseService`
2. Add migration logic in `_upgradeDB`
3. Test migration from previous versions
4. Consider data preservation

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models/judge_test.dart

# Run with coverage
flutter test --coverage
```

### Running the App

```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d ios
flutter run -d android
flutter run -d chrome

# Release mode
flutter run --release -d ios
```

### Building for Release

```bash
# iOS
flutter build ios --release

# Android
flutter build appbundle --release
flutter build apk --release
```

---

## Best Practices

### 1. Model Immutability
- All models are immutable
- Use `copyWith()` for updates
- Prevents accidental state mutations

### 2. Error Handling
- Repository methods catch and log errors
- UI layer handles errors via `AsyncValue.error`
- User-friendly error messages

### 3. Null Safety
- Leverage Dart's null safety
- Use `?` for optional fields
- Avoid `!` operator except when guaranteed

### 4. Performance
- Use indexes for frequently queried columns
- Paginate large lists
- Cache provider results automatically via Riverpod
- Lazy load event structures

### 5. Code Organization
- Group by feature, not type
- Keep files small and focused
- Extract reusable widgets
- Separate business logic from UI

### 6. Database Transactions
- Use transactions for multi-step operations
- Rollback on errors
- Maintain referential integrity

### 7. Date/Time Handling
- Store as ISO 8601 strings in database
- Convert to DateTime for logic
- Use `intl` package for formatting

---

## Future Enhancements

### Planned Features
- Cloud sync (Firebase/Supabase)
- Multi-user collaboration
- Advanced reporting with charts
- Expense receipt OCR
- Budget tracking and alerts
- Template library for common event structures
- Judge availability calendar
- Push notifications for assignments

### Technical Improvements
- Unit test coverage >80%
- Integration tests for critical flows
- Performance profiling
- Accessibility audit (WCAG compliance)
- i18n/l10n support
- Dark mode enhancements

---

## Troubleshooting

### Common Issues

**1. Database version conflicts**
- Delete app and reinstall
- Clear application data

**2. Code generation errors**
- Run `flutter clean`
- Run `flutter pub get`
- Regenerate with `build_runner`

**3. iOS build errors**
- Update CocoaPods: `pod repo update`
- Clean build: `cd ios && pod install && cd ..`

**4. Android build errors**
- Clean gradle: `cd android && ./gradlew clean && cd ..`
- Invalidate caches: Delete `build/` folder

---

## References

### Documentation
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Sqflite Documentation](https://pub.dev/packages/sqflite)

### Project Files
- [PROJECT_PLAN.md](PROJECT_PLAN.md) - Feature roadmap and requirements
- [FLUTTER_SETUP.md](FLUTTER_SETUP.md) - Development environment setup
- [README.md](README.md) - Getting started guide
- [JUDGE_CRUD_NOTES.md](JUDGE_CRUD_NOTES.md) - Judge management implementation notes
- [JUDGE_IMPORT_EXPORT.md](JUDGE_IMPORT_EXPORT.md) - Import/export system details
- [JUDGE_LEVEL_MIGRATION.md](JUDGE_LEVEL_MIGRATION.md) - Multi-certification migration guide
- [MEET_IMPORT_EXPORT_PLAN.md](MEET_IMPORT_EXPORT_PLAN.md) - Meet data exchange plan
- [MULTI_ASSOCIATION_MIGRATION.md](MULTI_ASSOCIATION_MIGRATION.md) - Association system refactoring

---

**Document Version**: 1.0  
**Last Updated**: December 11, 2025  
**Maintained By**: Development Team
