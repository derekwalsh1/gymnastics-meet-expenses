# Judge Import/Export Feature

## Overview
Complete implementation of judge import and export functionality using CSV files. This allows users to:
- Export all active judges with their certifications to CSV
- Import judges from CSV files (creating new or updating existing)
- Download a CSV template with example data
- Handle multiple certifications per judge

## Files Created

### 1. `/lib/services/judge_import_export_service.dart` (370 lines)
Core service handling all import/export operations.

**Key Methods:**

#### `exportJudgesToCsv({bool includeArchived = false})`
- Exports all judges with their certifications to CSV
- One row per certification (judges with multiple certifications get multiple rows)
- Includes: First Name, Last Name, Contact Info, Notes, Association, Level, Archived status
- Returns: `File` object of the created CSV

#### `importJudgesFromCsv(File csvFile)`
- Imports judges from CSV file
- Matches judges by first name + last name
- Creates new judges if no match found
- Updates existing judges if match found
- Assigns certifications based on association/level columns
- Returns: `ImportResult` with success status, counts, and error details

**Import Logic:**
- Groups rows by judge name to handle multiple certifications
- Validates CSV format and headers
- Checks if judge levels exist before assigning
- Skips duplicate certifications
- Provides detailed error reporting per row

#### `createSampleCsv()`
- Creates a template CSV with example data
- Includes 3 sample judges with various certification scenarios
- Returns: `File` object of the template

**ImportResult Model:**
```dart
class ImportResult {
  final bool success;
  final String message;
  final int judgesCreated;
  final int judgesUpdated;
  final int levelsAssigned;
  final List<String> errors;
}
```

### 2. `/lib/screens/judges/judge_import_export_screen.dart` (475 lines)
Full-featured UI for import/export operations.

**Features:**

#### Export Section
- Card-based UI with icon and description
- Single button to export all active judges
- Shares CSV file via system share sheet
- Shows success/failure status

#### Import Section
- File picker integration (CSV only)
- Detailed import notes explaining behavior
- Two buttons: "Import from CSV" and "Get Template"
- Processing indicator during import
- Success/error messaging with details

#### CSV Format Reference
- Visual guide showing required columns
- Tips about multiple certifications
- Formatted code blocks for clarity

#### Status Display
- Shows results of last operation
- Green card for success, orange for partial success with errors
- Scrollable error list for detailed feedback
- Shows counts: created, updated, levels assigned

**State Management:**
- `_isProcessing`: Shows loading indicator during operations
- `_lastOperationMessage`: Displays result summary
- `_lastErrors`: Collects and displays row-level errors
- Invalidates judge providers after successful import

## Integration Changes

### `/lib/main.dart`
Added route and import:
```dart
import 'screens/judges/judge_import_export_screen.dart';

GoRoute(
  path: '/judges/import-export',
  builder: (context, state) => const JudgeImportExportScreen(),
),
```

### `/lib/screens/judges/judges_list_screen.dart`
Updated import/export button:
```dart
IconButton(
  icon: const Icon(Icons.import_export),
  tooltip: 'Import/Export Judges',
  onPressed: () {
    context.push('/judges/import-export');
  },
),
```

## CSV Format

### Required Columns (in order):
1. **First Name** (required) - Judge's first name
2. **Last Name** (required) - Judge's last name  
3. **Contact Info** (optional) - Email or phone number
4. **Notes** (optional) - Any additional notes
5. **Association** (optional) - E.g., "USAG", "AAU"
6. **Level** (optional) - E.g., "National", "Level 3"
7. **Archived** (required) - "true" or "false"

### Example CSV:
```csv
First Name,Last Name,Contact Info,Notes,Association,Level,Archived
John,Smith,john.smith@email.com,Available most weekends,USAG,National,false
Jane,Doe,555-1234,,AAU,Level 3,false
Mike,Johnson,,Prefers local meets,,,false
```

### Multiple Certifications:
For judges certified in multiple associations/levels, include multiple rows:
```csv
First Name,Last Name,Contact Info,Notes,Association,Level,Archived
Sarah,Johnson,sarah@email.com,Senior judge,USAG,National,false
Sarah,Johnson,sarah@email.com,Senior judge,AAU,Level 4,false
```

## Import Behavior

### Matching Logic:
- Judges matched by exact first name + last name (case-insensitive)
- If match found: Updates contact info, notes, and archived status
- If no match: Creates new judge with provided information

### Certification Assignment:
- Association + Level must match an existing `JudgeLevel` in the database
- If level doesn't exist, logs error but continues processing
- Skips duplicate certifications (already assigned)
- Each successful certification increments `levelsAssigned` counter

### Error Handling:
- Row-level validation (shows specific row number in errors)
- Continues processing on errors (doesn't abort entire import)
- Collects all errors for display at end
- Partial success supported (some rows succeed, some fail)

## Dependencies Used

- **csv** (^5.1.1): CSV parsing and generation
- **file_picker** (^6.1.1): File selection for import
- **share_plus** (^7.2.1): Sharing exported files
- **path_provider** (^2.1.1): Getting app documents directory
- **uuid** (^4.2.2): Generating unique IDs

## User Flow

### Export Flow:
1. Navigate to Judges List
2. Tap Import/Export icon in app bar
3. Tap "Export Judges" button
4. System share sheet appears
5. Choose destination (Files, email, AirDrop, etc.)
6. CSV saved with timestamp in filename

### Import Flow:
1. Navigate to Judges → Import/Export
2. (Optional) Tap "Get Template" to download sample CSV
3. Prepare CSV file with judge data
4. Tap "Import from CSV"
5. Select CSV file from device
6. View import results:
   - Success message with counts
   - Error list if any rows failed
7. Judges list automatically refreshes

## Technical Notes

### Performance:
- Export processes all judges with their levels in one query
- Import batches operations but processes sequentially for data integrity
- Uses database transactions implicitly through repository methods

### Data Validation:
- Required fields: First Name, Last Name, Archived
- Association/Level validated against existing judge levels
- Archived accepts: "true", "1", "yes" (case-insensitive)
- Empty association/level allowed (judge without certifications)

### Error Recovery:
- Invalid rows skipped, valid rows processed
- Duplicate certifications ignored (not counted as errors)
- Missing judge levels logged but don't fail import
- File access errors caught and displayed

### iPad Compatibility:
- Share sheet positioned correctly using `sharePositionOrigin`
- File picker works natively on iOS
- Responsive card layout for all screen sizes

## Future Enhancements (Potential)

1. **Selective Export**: Export filtered judges only
2. **Include Archived**: Toggle to include archived judges in export
3. **Import Preview**: Show what will be created/updated before confirming
4. **Merge Strategies**: Options for handling conflicts (skip/update/ask)
5. **Bulk Operations**: Archive/unarchive via CSV
6. **Excel Support**: Import from .xlsx files
7. **Validation Report**: Downloadable report of import errors
8. **Certification Dates**: Include cert/expiration dates in CSV
9. **Backup/Restore**: Full database backup including events and expenses

## Testing Checklist

- ✅ Export judges with multiple certifications
- ✅ Export judges with no certifications  
- ✅ Export empty database (no judges)
- ✅ Import new judges
- ✅ Import updates to existing judges
- ✅ Import judges with multiple certifications
- ✅ Import with invalid association/level (error handling)
- ✅ Import with missing required fields (error handling)
- ✅ Import with malformed CSV (error handling)
- ✅ Download and use template
- ✅ Share exported file to various destinations
- ✅ iPad share sheet positioning
- ✅ Provider invalidation after import
- ✅ UI state during processing
- ✅ Error message display
- ✅ Success message display

## Known Limitations

1. **Judge Level Prerequisite**: Judge levels (associations and levels) must exist in the system before importing judges with certifications. Create levels first via Settings → Manage Judge Levels.

2. **Name Matching**: Judges are matched by first + last name only. Two judges with identical names will be treated as the same person.

3. **No Dry Run**: Import immediately creates/updates records. No preview or undo option.

4. **File Size**: Large CSV files (1000+ judges) not specifically tested or optimized.

5. **Encoding**: Assumes UTF-8 encoding. Other encodings may cause issues.

## Support Documentation

### For Users:
1. CSV template includes example data showing proper format
2. Import screen shows format reference
3. Error messages include row numbers for easy troubleshooting
4. Import notes explain behavior (create/update/skip)

### For Troubleshooting:
- Check that judge levels exist before importing
- Verify CSV format matches template exactly
- Review error list for specific row issues
- Ensure first and last names are non-empty
- Confirm "Archived" column contains only true/false
