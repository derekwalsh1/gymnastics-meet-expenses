# Meet Import/Export Implementation Plan

## Overview
Enable users to export complete meet structures (including all judges, fees, expenses) as JSON and import them on other devices.

## JSON Structure Design

```json
{
  "version": "1.0",
  "exportDate": "2025-12-08T10:30:00.000Z",
  "exportedBy": "App v1.0.0+7",
  "meet": {
    "id": "meet-uuid",
    "name": "State Championships 2025",
    "startDate": "2025-03-15T09:00:00.000Z",
    "endDate": "2025-03-17T17:00:00.000Z",
    "location": {
      "venueName": "Convention Center",
      "city": "Denver",
      "state": "CO",
      "country": "USA"
    },
    "description": "Annual state championships",
    "totalBudget": 50000.00,
    "associationId": "nawgj",
    "status": "planning"
  },
  "sessions": [
    {
      "id": "session-uuid",
      "eventId": "meet-uuid",
      "name": "Session 1 - Thursday AM",
      "date": "2025-03-15T09:00:00.000Z",
      "startTime": "09:00",
      "endTime": "12:00",
      "level": "Level 10",
      "ageGroup": "15-18",
      "meetType": "all_around",
      "description": null
    }
  ],
  "floors": [
    {
      "id": "floor-uuid",
      "sessionId": "session-uuid",
      "apparatus": "vault",
      "assignment": "equipment_manager",
      "durationMinutes": 20,
      "notes": null
    }
  ],
  "days": [
    {
      "id": "day-uuid",
      "eventId": "meet-uuid",
      "dayNumber": 1,
      "date": "2025-03-15",
      "description": null
    }
  ],
  "judgeAssignments": [
    {
      "id": "assignment-uuid",
      "judgeId": "judge-uuid",
      "eventId": "meet-uuid",
      "sessionId": "session-uuid",
      "floorId": "floor-uuid",
      "assignmentRole": "floor_judge",
      "hourlyRate": 50.00,
      "estimatedHours": 3.0
    }
  ],
  "judges": [
    {
      "id": "judge-uuid",
      "firstName": "Alice",
      "lastName": "Anderson",
      "contactInfo": "alice@example.com",
      "notes": "Experienced judge",
      "isArchived": false,
      "certifications": [
        {
          "association": "NAWGJ",
          "level": "National"
        }
      ]
    }
  ],
  "fees": [
    {
      "id": "fee-uuid",
      "judgeAssignmentId": "assignment-uuid",
      "feeType": "session_rate",
      "description": "Session rate for Thursday AM",
      "amount": 150.00,
      "hours": 3.0,
      "isAutoCalculated": true,
      "isTaxable": true,
      "createdAt": "2025-12-08T10:00:00.000Z",
      "updatedAt": "2025-12-08T10:00:00.000Z"
    }
  ],
  "expenses": [
    {
      "id": "expense-uuid",
      "eventId": "meet-uuid",
      "judgeId": "judge-uuid",
      "sessionId": null,
      "judgeAssignmentId": null,
      "category": "mileage",
      "distance": 125.5,
      "mileageRate": 0.67,
      "mealType": null,
      "perDiemRate": null,
      "transportationType": null,
      "checkInDate": null,
      "checkOutDate": null,
      "numberOfNights": null,
      "amount": 84.09,
      "isAutoCalculated": true,
      "date": "2025-03-15T09:00:00.000Z",
      "description": "Mileage to venue",
      "receiptPhotoPath": null,
      "createdAt": "2025-12-08T10:00:00.000Z",
      "updatedAt": "2025-12-08T10:00:00.000Z"
    }
  ]
}
```

## Implementation Steps

### Phase 1: Service Layer
1. **Create `meet_import_export_service.dart`**
   - `Future<File> exportMeet(String eventId)` - Export complete meet with all related data
   - `Future<MeetImportResult> importMeet(File jsonFile)` - Import meet and all related data
   - Handle ID remapping (old IDs → new UUIDs on import)
   - Platform-specific file saving (iOS vs Android)

2. **Handle Related Data**
   - Fetch and serialize: event, sessions, floors, days, judge assignments, judges, fees, expenses
   - Preserve relationships via IDs
   - Handle null/optional fields properly

3. **Import Logic**
   - Validate JSON structure
   - Generate new UUIDs for all entities (prevent ID conflicts)
   - Build ID mapping (old → new)
   - Update all foreign key references
   - Create in order: Event → Sessions → Floors → Days → Judges → Judge Assignments → Fees → Expenses
   - Rollback on any error

### Phase 2: UI Screens
1. **Create `meet_export_screen.dart`**
   - Button on meet details to export
   - Show progress during export
   - Option to include archived judges
   - Success message with file location
   - Share button to send via email/cloud

2. **Create `meet_import_screen.dart`**
   - File picker (JSON files only)
   - Validation before import
   - Preview of import contents (meet name, judges count, expenses count)
   - Import progress indicator
   - Results summary: created/updated counts, errors
   - Cancel import option

### Phase 3: Integration
1. **Add to meet details/settings screen**
   - Export button
   - Import button (if viewing empty meet or during setup)

2. **Navigation**
   - Handle file selection and deep linking
   - Import from Files app or email attachment

## Key Considerations

### ID Mapping During Import
```dart
Map<String, String> idMap = {}; // old ID → new ID

// When creating new entities:
String newId = uuid.v4();
idMap[oldId] = newId;

// When updating references:
String? newRefId = idMap[oldRefId];
```

### Data Validation
- Ensure all referenced judges exist or are created
- Validate date ranges
- Verify expense/fee amounts are positive
- Check judge certifications align with assignments

### Error Handling
- Duplicate judge IDs/names on import
- Missing referenced entities
- Corrupted JSON structure
- File access errors (permissions)
- Insufficient storage space

### Platform Differences
- **Android**: Save to Downloads folder for easy access
- **iOS**: Save to app documents (user shares via Files app)

### Performance
- Stream large files instead of loading entire JSON
- Show progress for large meets with many judges/expenses
- Allow cancellation mid-import

### Testing Data
- Use `test_judges_60.json` as sample judge data
- Create test meets with various expense types
- Verify round-trip consistency (export → import → export should be identical)

## Files to Create
1. `lib/services/meet_import_export_service.dart` - Main service
2. `lib/screens/meets/meet_export_screen.dart` - Export UI
3. `lib/screens/meets/meet_import_screen.dart` - Import UI
4. `lib/models/meet_import_export_result.dart` - Result data classes

## Database Considerations
- Use transaction for import (atomic operation)
- Prevent partial imports on failure
- Handle cascade deletes if needed

## Future Enhancements
- Cloud sync (automatic backup to cloud)
- Version compatibility checking
- Selective import (choose which data to import)
- Merge meets (combine multiple exports)
- Meet templates for quick setup
