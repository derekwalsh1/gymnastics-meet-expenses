# Event Structure Cloning Feature

**Feature Added:** December 11, 2025  
**Status:** Implemented

---

## Overview

The cloning feature allows users to quickly duplicate event days, sessions, and floors along with their judge assignments. This significantly speeds up event setup when multiple days or sessions have similar structures.

## Use Cases

### 1. Clone Day
**When to use:** Most gymnastics meets have multiple days with identical or similar session structures.

**Example:**
- Day 1 has Morning, Afternoon, and Evening sessions
- Clone Day 1 to create Day 2 with the same structure
- Just update the date and any specific details

**What gets cloned:**
- All sessions within the day
- All floors within each session
- (Optional) Judge assignments to each floor
- Session times and details
- Floor names, colors, and configuration

### 2. Clone Session
**When to use:** A day has multiple sessions with the same floor layout.

**Example:**
- Morning session has Vault, Bars, Beam, Floor apparatus
- Clone the morning session to create afternoon session
- Update the session time
- Keep the same floor structure and judges

**What gets cloned:**
- All floors within the session
- (Optional) Judge assignments to each floor
- Floor names, colors, and configuration

### 3. Clone Floor
**When to use:** Need multiple floors with the same apparatus or setup.

**Example:**
- Session has Floor Exercise apparatus with 2 judges
- Clone to create additional Floor Exercise floors
- Keeps the same judge assignments

**What gets cloned:**
- Floor configuration
- (Optional) Judge assignment

---

## Implementation Details

### Repository Methods

#### EventDayRepository
```dart
Future<EventDay> cloneEventDay({
  required String eventDayId,
  required DateTime newDate,
  bool includeJudgeAssignments = true,
}) async
```

**Behavior:**
- Creates new day with incremented day number
- Clones all sessions recursively
- Each session clones its floors
- Each floor optionally clones its judge assignments
- Adds "(cloned)" notation to notes

#### EventSessionRepository
```dart
Future<EventSession> cloneEventSession({
  required String eventSessionId,
  String? newEventDayId,  // Optional: clone to different day
  bool includeJudgeAssignments = true,
}) async
```

**Behavior:**
- Creates new session with incremented session number
- Can clone to a different day if specified
- Clones all floors recursively
- Each floor optionally clones its judge assignments
- Appends "(cloned)" to session name

#### EventFloorRepository
```dart
Future<EventFloor> cloneEventFloor({
  required String eventFloorId,
  String? newEventSessionId,  // Optional: clone to different session
  bool includeJudgeAssignments = true,
}) async
```

**Behavior:**
- Creates new floor with incremented floor number
- Can clone to a different session if specified
- Optionally clones judge assignment
- Preserves floor name
- Adds "(cloned)" to notes

#### JudgeAssignmentRepository
```dart
Future<JudgeAssignment> cloneAssignment({
  required String assignmentId,
  required String newEventFloorId,
}) async
```

**Behavior:**
- Creates new assignment with same judge details
- Links to new floor
- Preserves hourly rate
- Auto-creates session fee based on new session duration

---

## User Interface

### Clone Day Dialog
**Location:** Event Day Detail Screen → Menu → Clone Day

**Options:**
- Select new date (defaults to next day)
- Include/exclude judge assignments (checkbox)

**Actions:**
- Cancel: Dismisses dialog
- Clone Day: Creates the clone and returns to structure screen

### Clone Session Dialog
**Location:** 
- Event Day Detail Screen → Session card → Menu → Clone Session
- Event Session Detail Screen → Menu → Clone Session

**Options:**
- Include/exclude judge assignments (checkbox)

**Actions:**
- Cancel: Dismisses dialog
- Clone Session: Creates the clone within the same day

### Clone Floor Dialog
**Location:** Event Session Detail Screen → Floor card → Menu → Clone Floor

**Options:**
- Include/exclude judge assignment (checkbox)

**Actions:**
- Cancel: Dismisses dialog
- Clone Floor: Creates the clone within the same session

---

## Technical Details

### ID Generation
- All cloned entities receive new UUIDs
- Maintains referential integrity through foreign keys

### Number Sequencing
- Day numbers automatically increment from highest existing
- Session numbers automatically increment within day
- Floor numbers automatically increment within session

### Data Preservation
- Preserves all configuration details
- Copies judge snapshot data (name, level, rate)
- Maintains relationships (day → sessions → floors → assignments)

### Notes Tracking
- Original notes are preserved and appended with "(cloned)"
- If no notes exist, adds "Cloned from [Type] [Number]"
- Helps identify cloned structures for auditing

### State Management
- Invalidates relevant providers after cloning
- Triggers UI refresh automatically
- Shows success/error messages

---

## Benefits

### Time Savings
- **Without cloning:** Create 3-day meet = Create day 1 manually (10 min) + Create day 2 manually (10 min) + Create day 3 manually (10 min) = **30 minutes**
- **With cloning:** Create day 1 manually (10 min) + Clone day 1 to day 2 (10 sec) + Clone day 1 to day 3 (10 sec) = **~10 minutes**

### Consistency
- Ensures identical structure across days/sessions
- Reduces errors from manual re-entry
- Maintains judge assignments when appropriate

### Flexibility
- Option to include or exclude judge assignments
- Can modify cloned structures afterward
- Non-destructive (doesn't affect original)

---

## Usage Workflow

### Typical Multi-Day Meet Setup

1. **Create Event** with basic details
2. **Add Day 1** manually
3. **Add Sessions to Day 1** (Morning, Afternoon, Evening)
4. **Add Floors to Morning Session** (Vault, Bars, Beam, Floor)
5. **Clone Morning Session** → creates Afternoon session with same floors
6. **Clone Morning Session** → creates Evening session with same floors
7. **Assign Judges** to all floors
8. **Clone Day 1** → creates Day 2 with all sessions, floors, and judges
9. **Clone Day 1** → creates Day 3 with all sessions, floors, and judges
10. **Adjust** any day-specific details (dates, judge assignments)

**Result:** 3-day meet with 3 sessions per day, 4 floors per session = 36 floor assignments created from ~16 manual operations + 5 clone operations instead of 36 manual operations.

---

## Future Enhancements

### Potential Improvements
- **Bulk clone:** Clone multiple days at once
- **Template system:** Save event structures as templates
- **Smart clone:** Detect similar structures and suggest cloning
- **Partial clone:** Select specific sessions/floors to include
- **Cross-event clone:** Clone structure from previous events
- **Clone scheduling:** Clone but adjust times by offset

---

## Code Changes

### Files Modified
1. `/lib/repositories/event_day_repository.dart` - Added `cloneEventDay` method
2. `/lib/repositories/event_session_repository.dart` - Added `cloneEventSession` method
3. `/lib/repositories/event_floor_repository.dart` - Added `cloneEventFloor` method
4. `/lib/repositories/judge_assignment_repository.dart` - Added `cloneAssignment` method
5. `/lib/screens/events/event_day_detail_screen.dart` - Added clone UI for days and sessions
6. `/lib/screens/events/event_session_detail_screen.dart` - Added clone UI for sessions and floors

### Files Updated for Documentation
- `/ARCHITECTURE.md` - Added clone operations section
- `/CLONING_FEATURE.md` - This document

---

## Testing Recommendations

### Manual Testing Checklist
- [ ] Clone day with judge assignments included
- [ ] Clone day with judge assignments excluded
- [ ] Clone session with judge assignments included
- [ ] Clone session with judge assignments excluded
- [ ] Clone floor with judge assignment included
- [ ] Clone floor with judge assignment excluded
- [ ] Verify cloned entities have unique IDs
- [ ] Verify number sequencing (day, session, floor)
- [ ] Verify judge fees are recalculated for cloned assignments
- [ ] Verify notes include "(cloned)" notation
- [ ] Delete original after cloning (ensure clone is independent)
- [ ] Edit cloned entity (ensure changes don't affect original)

### Edge Cases
- [ ] Clone when no sessions exist in day
- [ ] Clone when no floors exist in session
- [ ] Clone when no judge assigned to floor
- [ ] Clone to event with existing days (number conflict)
- [ ] Clone with network/database errors

---

## Support & Troubleshooting

### Common Issues

**Issue:** Clone operation shows error
- **Solution:** Check database connection, ensure original entity exists

**Issue:** Cloned day has wrong number
- **Solution:** Numbers auto-increment from highest; this is expected behavior

**Issue:** Judge assignments not cloned
- **Solution:** Ensure "Include judge assignments" is checked in dialog

**Issue:** Cloned session has same time as original
- **Solution:** Times are preserved; manually edit session times after cloning

---

**Documentation Version:** 1.0  
**Last Updated:** December 11, 2025
