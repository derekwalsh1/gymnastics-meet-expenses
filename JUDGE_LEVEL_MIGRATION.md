# Judge Level System Implementation

## Changes Made

### New Models
- ✅ `JudgeLevel` - Association, level, and default hourly rate
- ✅ `JudgeWithLevel` - Helper model combining Judge + JudgeLevel details

### Updated Models
- ✅ `Judge` - Now uses `judgeLevelId` instead of separate association/level/hourlyRate fields

### Database Changes
- ✅ New `judge_levels` table with pre-populated data
- ✅ Updated `judges` table with foreign key to `judge_levels`
- ✅ Automatic insertion of default NAWGJ and NGA levels on database creation

### Default Judge Levels
```
NAWGJ 6-8: $25/hr
NAWGJ 4-5: $20/hr
NAWGJ Nine: $30/hr
NAWGJ Ten: $35/hr
NAWGJ Brevet: $40/hr
NAWGJ National: $50/hr
NGA Local: $15/hr
NGA State: $20/hr
NGA Regional: $25/hr
NGA National: $35/hr
NGA Elite: $45/hr
```

### New Repositories
- ✅ `JudgeLevelRepository` - CRUD operations for judge levels

### Updated Repositories
- ✅ `JudgeRepository` - Updated to work with judge levels
- ✅ Added `getJudgesWithLevels()` method to join judges with their level details

### New Providers
- ✅ `JudgeLevelProvider` - State management for judge levels
- ✅ `judgesWithLevelsProvider` - Provides judges with their full level details

### Updated UI
- ✅ `JudgesListScreen` - Now displays judges with their level info
- ✅ `AddEditJudgeScreen` - Dropdown to select judge level instead of manual entry

## Database Migration Required

**IMPORTANT**: Since the database schema changed, you need to clear the old database:

### Option 1: Uninstall and Reinstall App
1. Stop the running app
2. Uninstall from simulator/device
3. Run `flutter run` again

### Option 2: Clear App Data (iOS Simulator)
```bash
xcrun simctl uninstall booted com.nawgj.nawgjExpenseTracker
```

### Option 3: Delete Database Manually
The database file is typically at:
`~/Library/Developer/CoreSimulator/Devices/<device-id>/data/Containers/Data/Application/<app-id>/Documents/nawgj_expense_tracker.db`

## Next Steps

1. Clear old database (use one of the options above)
2. Run `flutter pub run build_runner build --delete-conflicting-outputs` to generate JSON code
3. Restart the app
4. The database will be created with the new schema and pre-populated judge levels

## Future Enhancements

- Add UI to manage judge levels (add/edit/delete custom levels)
- Import/export judge levels along with judges
- Allow override of hourly rate per judge (use level default as starting point)
