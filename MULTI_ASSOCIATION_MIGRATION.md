# Multi-Association Support Migration Notes

## Database Changes (v3)

### New Tables
- `judge_certifications` - Junction table for many-to-many relationship between judges and judge levels
  - id, judgeId, judgeLevelId, certificationDate, expirationDate, createdAt, updatedAt
  - Unique constraint on (judgeId, judgeLevelId)

### Modified Tables
- `judges` - Removed `judgeLevelId` foreign key column
- `events` - Added `associationId` field to track which association oversees the event

### Migration Strategy
- Existing judges are migrated by creating a certification record in `judge_certifications`
- All existing data preserved during migration from v2 to v3

## Model Changes

### New Models
- `JudgeCertification` - Represents a judge's certification in a specific level

### Modified Models
- `Judge` - Removed `judgeLevelId` field
- `JudgeWithLevel` → `JudgeWithLevels` - Now holds a list of levels instead of single level
  - `levels: List<JudgeLevel>` 
  - New methods: `associations`, `certificationsDisplay`, `levelsFor(association)`, `hasCertificationIn(association)`, `maxHourlyRate`

## Repository Updates Needed

1. **JudgeRepository** - Update all queries to JOIN with judge_certifications
   - `getJudgesWithLevels()` → Returns `List<JudgeWithLevels>`
   - Need to group certifications by judge
   - `addJudge()` - No longer takes judgeLevelId
   
2. **New: JudgeCertificationRepository** - CRUD for managing judge certifications
   - `addCertification(judgeId, judgeLevelId)`
   - `removeCertification(judgeId, judgeLevelId)`
   - `getCertificationsForJudge(judgeId)`
   - `getJudgesWithLevel(judgeLevelId)`

## Provider Updates Needed

1. **Judge Providers** - Update return types
   - `judgesWithLevelsProvider` → Returns `List<JudgeWithLevels>`
   - `filteredJudgesWithLevelsProvider` → Returns `List<JudgeWithLevels>`
   
2. **New: Certification Provider** - Manage certifications separately

## UI Updates Needed

1. **AddEditJudgeScreen** - Major refactor
   - Remove single level dropdown
   - Add multi-select for certifications
   - Show list of current certifications with add/remove buttons
   - Can select from all available judge levels across all associations

2. **JudgesListScreen** - Update to show multiple certifications
   - Display all certifications in subtitle
   - Filter by association

3. **JudgeCard** - Show all certifications

4. **Events** - Add association selection

## Current Status
- ✅ Database migration created (v3)
- ✅ JudgeCertification model created
- ✅ Judge model updated (judgeLevelId removed)
- ✅ JudgeWithLevels model created
- ⏳ Need to run build_runner for judge.g.dart and judge_certification.g.dart
- ❌ JudgeCertificationRepository - not created yet
- ❌ JudgeRepository - needs updates for new schema
- ❌ Providers - need updates
- ❌ UI screens - need major refactoring

## Next Steps
1. Create JudgeCertificationRepository
2. Update JudgeRepository to work with new schema
3. Update providers
4. Refactor AddEditJudgeScreen for multi-select certifications
5. Update JudgesListScreen to display multiple certifications
6. Add association field to Event management

## Breaking Changes
This is a breaking database migration. Existing judge data will be migrated automatically, but the UI and data flow changes significantly.
