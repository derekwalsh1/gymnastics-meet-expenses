# Event Implementation Plan

## Overview
Implementation plan for the complete event management system with hierarchical structure (Event → Day → Session → Floor → Judge Assignments) and expense tracking.

## Event Structure

### Hierarchy
```
Event
├── Event Details (name, dates, location, association)
├── Event Days (1 or more)
│   └── Sessions (1 or more per day)
│       └── Floors (1 or more per session)
│           └── Judge Assignments (1 or more per floor)
│               ├── Judge Snapshot (copied data)
│               ├── Fees (1 or more, taxable)
│               └── Expenses (0 or more, non-taxable)
```

### Business Rules
1. **Multi-level Structure**: Events can span multiple days, have multiple sessions per day, and multiple floors per session
2. **Judge Assignments**: 
   - Judges can work multiple sessions across multiple days
   - Judges CANNOT work multiple floors simultaneously (same time slot = one floor only)
   - Judge info is COPIED (snapshot) when assigned, not referenced
3. **Financial Tracking**:
   - **Fees** (taxable): Judge hourly rate × session duration, additional fees (meet referee, head judge, etc.)
   - **Expenses** (non-taxable): Mileage, meals, lodging, travel, etc.
4. **Templates**: Support common event patterns (single day/session/floor, multi-day multi-session, etc.)

## Database Schema (Version 4)

### New Tables

#### `event_days`
```sql
CREATE TABLE event_days (
  id TEXT PRIMARY KEY,
  eventId TEXT NOT NULL,
  dayNumber INTEGER NOT NULL,  -- 1-based index
  date TEXT NOT NULL,           -- ISO8601 date
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE,
  UNIQUE(eventId, dayNumber)
);
CREATE INDEX idx_event_days_eventId ON event_days(eventId);
```

#### `event_sessions`
```sql
CREATE TABLE event_sessions (
  id TEXT PRIMARY KEY,
  eventDayId TEXT NOT NULL,
  sessionNumber INTEGER NOT NULL,  -- 1-based index for the day
  name TEXT NOT NULL,               -- e.g., "Morning Session", "Session 1"
  startTime TEXT NOT NULL,          -- Time only (HH:mm)
  endTime TEXT NOT NULL,            -- Time only (HH:mm)
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventDayId) REFERENCES event_days(id) ON DELETE CASCADE,
  UNIQUE(eventDayId, sessionNumber)
);
CREATE INDEX idx_event_sessions_eventDayId ON event_sessions(eventDayId);
```

#### `event_floors`
```sql
CREATE TABLE event_floors (
  id TEXT PRIMARY KEY,
  eventSessionId TEXT NOT NULL,
  floorNumber INTEGER NOT NULL,     -- 1-based index for the session
  name TEXT NOT NULL,                -- e.g., "Floor A", "Competition Floor 1"
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventSessionId) REFERENCES event_sessions(id) ON DELETE CASCADE,
  UNIQUE(eventSessionId, floorNumber)
);
CREATE INDEX idx_event_floors_eventSessionId ON event_floors(eventSessionId);
```

#### `judge_assignments`
```sql
CREATE TABLE judge_assignments (
  id TEXT PRIMARY KEY,
  eventFloorId TEXT NOT NULL,
  
  -- Snapshot of judge data (copied, not referenced)
  judgeId TEXT NOT NULL,              -- Original judge ID for reference only
  judgeFirstName TEXT NOT NULL,
  judgeLastName TEXT NOT NULL,
  judgeAssociation TEXT NOT NULL,     -- Association for this assignment
  judgeLevel TEXT NOT NULL,
  judgeContactInfo TEXT,
  
  -- Assignment details
  role TEXT,                          -- e.g., "Head Judge", "D1 Judge", "E Judge"
  hourlyRate REAL NOT NULL,           -- Copied from judge level or custom
  
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventFloorId) REFERENCES event_floors(id) ON DELETE CASCADE
);
CREATE INDEX idx_judge_assignments_eventFloorId ON judge_assignments(eventFloorId);
CREATE INDEX idx_judge_assignments_judgeId ON judge_assignments(judgeId);
```

#### `judge_fees`
```sql
CREATE TABLE judge_fees (
  id TEXT PRIMARY KEY,
  judgeAssignmentId TEXT NOT NULL,
  
  feeType TEXT NOT NULL,              -- 'session_rate', 'meet_referee', 'head_judge', 'custom'
  description TEXT NOT NULL,          -- e.g., "Session Judge Fee", "Meet Referee Bonus"
  amount REAL NOT NULL,               -- Dollar amount
  hours REAL,                         -- For hourly rates (auto-calculated from session times)
  isAutoCalculated INTEGER NOT NULL,  -- 1 if calculated from hourly rate × hours
  isTaxable INTEGER NOT NULL DEFAULT 1, -- Always 1 for fees
  
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (judgeAssignmentId) REFERENCES judge_assignments(id) ON DELETE CASCADE
);
CREATE INDEX idx_judge_fees_judgeAssignmentId ON judge_fees(judgeAssignmentId);
```

#### `judge_expenses` (replaces/extends existing expenses table)
```sql
-- Note: This extends the existing expenses table structure
-- Add new columns to existing expenses table:
ALTER TABLE expenses ADD COLUMN judgeAssignmentId TEXT;
ALTER TABLE expenses ADD COLUMN feeType TEXT; -- NULL for expenses

-- Update foreign key relationship
CREATE INDEX idx_expenses_judgeAssignmentId ON expenses(judgeAssignmentId);
```

### Updates to Existing Tables

#### `events` table
```sql
-- Add association tracking (already exists from v3)
-- associationId field already present
-- No changes needed
```

## Data Models

### Core Models

#### `lib/models/event_day.dart`
```dart
class EventDay {
  final String id;
  final String eventId;
  final int dayNumber;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### `lib/models/event_session.dart`
```dart
class EventSession {
  final String id;
  final String eventDayId;
  final int sessionNumber;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Helper methods
  Duration get duration;
  double get durationInHours;
}
```

#### `lib/models/event_floor.dart`
```dart
class EventFloor {
  final String id;
  final String eventSessionId;
  final int floorNumber;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### `lib/models/judge_assignment.dart`
```dart
class JudgeAssignment {
  final String id;
  final String eventFloorId;
  
  // Judge snapshot data
  final String judgeId;
  final String judgeFirstName;
  final String judgeLastName;
  final String judgeAssociation;
  final String judgeLevel;
  final String? judgeContactInfo;
  
  // Assignment details
  final String? role;
  final double hourlyRate;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Helper methods
  String get judgeFullName => '$judgeFirstName $judgeLastName';
}
```

#### `lib/models/judge_fee.dart`
```dart
enum FeeType {
  sessionRate,    // Auto-calculated: hourlyRate × session hours
  meetReferee,    // Fixed bonus
  headJudge,      // Fixed bonus
  custom,         // User-defined
}

class JudgeFee {
  final String id;
  final String judgeAssignmentId;
  final FeeType feeType;
  final String description;
  final double amount;
  final double? hours;
  final bool isAutoCalculated;
  final bool isTaxable; // Always true for fees
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Composite Models

#### `lib/models/event_with_structure.dart`
```dart
class EventWithStructure {
  final Event event;
  final List<EventDayWithSessions> days;
  
  // Helper methods
  int get totalDays;
  int get totalSessions;
  int get totalFloors;
  int get totalJudges;
  double get totalFees;
  double get totalExpenses;
  double get grandTotal;
}

class EventDayWithSessions {
  final EventDay day;
  final List<EventSessionWithFloors> sessions;
}

class EventSessionWithFloors {
  final EventSession session;
  final List<EventFloorWithAssignments> floors;
}

class EventFloorWithAssignments {
  final EventFloor floor;
  final List<JudgeAssignmentWithFinancials> assignments;
}

class JudgeAssignmentWithFinancials {
  final JudgeAssignment assignment;
  final List<JudgeFee> fees;
  final List<Expense> expenses;
  
  double get totalFees;
  double get totalExpenses;
  double get total;
}
```

## Event Templates

### Template Types

#### `lib/models/event_template.dart`
```dart
enum EventTemplateType {
  singleDaySingleSession,      // 1 day, 1 session, 1 floor
  singleDayMultiSession,       // 1 day, 2+ sessions, 1 floor each
  multiDaySingleSession,       // 2+ days, 1 session per day, 1 floor
  multiDayMultiSession,        // 2+ days, 2+ sessions per day, 1 floor each
  largeMeetMultiFloor,         // 2+ days, 2+ sessions, 2+ floors
}

class EventTemplate {
  final EventTemplateType type;
  final String name;
  final String description;
  final int days;
  final int sessionsPerDay;
  final int floorsPerSession;
  
  // Default time suggestions
  final List<SessionTimeTemplate> sessionTimes;
}

class SessionTimeTemplate {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
}
```

### Pre-defined Templates

1. **Quick Meet** (singleDaySingleSession)
   - 1 day, 1 session (9:00 AM - 5:00 PM), 1 floor
   
2. **Standard Meet** (singleDayMultiSession)
   - 1 day, 2 sessions (Morning: 8:00 AM - 12:00 PM, Afternoon: 1:00 PM - 5:00 PM), 1 floor each
   
3. **Weekend Meet** (multiDayMultiSession)
   - 2 days (Sat/Sun), 2 sessions per day, 1 floor each
   
4. **Championship Meet** (largeMeetMultiFloor)
   - 3 days, 3 sessions per day, 2 floors per session

## Implementation Phases

### Phase 1: Core Event Structure (Current Sprint)
- [ ] Create database migration v3 → v4
- [ ] Implement event_days, event_sessions, event_floors tables
- [ ] Create data models for EventDay, EventSession, EventFloor
- [ ] Create repositories for days, sessions, floors
- [ ] Create providers for event structure

### Phase 2: Event CRUD UI
- [ ] Event creation wizard with template selection
- [ ] Day management (add/edit/delete days)
- [ ] Session management with time pickers
- [ ] Floor management
- [ ] Event detail screen with hierarchical view

### Phase 3: Judge Assignment System
- [ ] Create judge_assignments table and model
- [ ] Judge assignment UI (filter by event's association)
- [ ] Conflict detection (same time slot check)
- [ ] Judge snapshot creation (copy data)
- [ ] Auto-calculate session fee from hourly rate

### Phase 4: Fee Management
- [ ] Create judge_fees table and model
- [ ] Fee repository and providers
- [ ] UI for adding custom fees (meet referee, head judge, etc.)
- [ ] Auto-calculation of session fees

### Phase 5: Expense Tracking
- [ ] Link expenses to judge assignments
- [ ] Expense entry UI per judge per event
- [ ] Category-specific expense forms
- [ ] Receipt photo capture

### Phase 6: Financial Reporting
- [ ] Event financial summary
- [ ] Per-judge expense/fee breakdown
- [ ] Export to PDF/CSV for 1099 prep
- [ ] Taxable vs non-taxable reporting

## Key UI Screens

### Event Management
1. **Events List Screen** (existing, needs enhancement)
   - Show event cards with date range, location, status
   - Quick stats: days, sessions, judges assigned
   
2. **Create Event Screen** (wizard)
   - Step 1: Basic info (name, dates, location, association)
   - Step 2: Template selection
   - Step 3: Customize structure (days/sessions/floors)
   - Step 4: Review and create

3. **Event Detail Screen**
   - Hierarchical tree view: Days → Sessions → Floors → Judges
   - Financial summary (total fees, expenses, grand total)
   - Quick actions: Add day, Add session, Assign judge

4. **Session Detail Screen**
   - Session info (date, time, duration)
   - Floor list with judge counts
   - Assign judges to floors

5. **Judge Assignment Screen**
   - Filter judges by event's association
   - Show available judges (not on another floor at same time)
   - Confirm hourly rate (from judge level or custom)
   - Assign role (optional)

6. **Judge Financials Screen**
   - Per judge, per event view
   - Fees section (session fees, bonuses)
   - Expenses section (categorized)
   - Total breakdown (taxable fees, non-taxable expenses)

## Migration Strategy

### Database Migration v3 → v4
```sql
-- Add new tables
CREATE TABLE event_days (...);
CREATE TABLE event_sessions (...);
CREATE TABLE event_floors (...);
CREATE TABLE judge_assignments (...);
CREATE TABLE judge_fees (...);

-- Extend expenses table
ALTER TABLE expenses ADD COLUMN judgeAssignmentId TEXT;
CREATE INDEX idx_expenses_judgeAssignmentId ON expenses(judgeAssignmentId);

-- Data migration: No existing events to migrate (events not implemented yet)
```

## Technical Considerations

### Time Handling
- Store dates as ISO8601 strings in database
- Store times as "HH:mm" strings (TimeOfDay in Flutter)
- Calculate durations in application layer
- Handle timezone conversions for display

### Conflict Detection
```dart
// Check if judge is already assigned to another floor at the same time
Future<bool> hasConflict(String judgeId, String eventSessionId) async {
  // Get session time range
  // Query all floors for this session
  // Check if judge is assigned to any floor
  // Return true if conflict exists
}
```

### Snapshot Strategy
```dart
// When assigning judge to floor, copy current data
JudgeAssignment createAssignment(JudgeWithLevels judge, String association, String floorId) {
  final level = judge.levelsFor(association).first;
  return JudgeAssignment(
    judgeId: judge.judge.id,
    judgeFirstName: judge.judge.firstName,
    judgeLastName: judge.judge.lastName,
    judgeAssociation: association,
    judgeLevel: level.level,
    hourlyRate: level.defaultHourlyRate,
    // ... snapshot preserves data even if judge record is updated later
  );
}
```

### Auto-calculation
```dart
// Auto-create session fee when judge is assigned
JudgeFee createSessionFee(JudgeAssignment assignment, EventSession session) {
  final hours = session.durationInHours;
  return JudgeFee(
    feeType: FeeType.sessionRate,
    description: 'Session Judge Fee',
    amount: assignment.hourlyRate * hours,
    hours: hours,
    isAutoCalculated: true,
    isTaxable: true,
  );
}
```

## Next Steps

1. Review and approve this plan
2. Begin Phase 1 implementation:
   - Database migration script
   - Core models (EventDay, EventSession, EventFloor)
   - Repositories and providers
3. Build event creation wizard with template support
4. Implement hierarchical event detail view

## Notes
- Keep judge data as snapshot (copy) not reference
- All fees are taxable (for 1099 reporting)
- All expenses are non-taxable
- Templates speed up common event setups
- Conflict detection prevents scheduling errors
- Financial reporting separated by taxable/non-taxable for compliance
