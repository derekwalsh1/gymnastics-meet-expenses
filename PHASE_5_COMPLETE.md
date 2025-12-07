# Phase 5: Expense Tracking - Implementation Complete

## Overview
Successfully implemented comprehensive expense tracking system for the NAWGJ Expense Tracker app. Judges can now record all event-related expenses with category-specific fields, automatic calculations, and receipt photo management.

## Implementation Summary

### 1. Model Updates ✅
**File**: `lib/models/expense.dart`
- Added `judgeAssignmentId` field to link expenses to specific judge assignments
- Updated constructor, copyWith, toMap, and fromMap methods
- Regenerated `expense.g.dart` with build_runner
- Supports 9 expense categories: mileage, meals, lodging, airfare, parking, tolls, rental car, transportation, other
- Category-specific fields:
  - **Mileage**: distance, mileageRate (IRS standard $0.67/mile)
  - **Meals**: mealType (breakfast/lunch/dinner/snack), perDiemRate
  - **Lodging**: checkInDate, checkOutDate, numberOfNights (auto-calculated)
  - **Transportation**: transportationType
- Auto-calculation flag for computed amounts
- Receipt photo path storage

### 2. Repository Layer ✅
**File**: `lib/repositories/expense_repository.dart` (237 lines)
- Complete CRUD operations:
  - `createExpense()` - with all category-specific parameters
  - `getExpenseById()` - single expense retrieval
  - `updateExpense()` - update existing expense
  - `deleteExpense()` - remove expense
- Query methods:
  - `getExpensesByEventId()` - all expenses for an event
  - `getExpensesByJudgeId()` - all expenses for a judge
  - `getExpensesByAssignmentId()` - expenses for specific assignment
  - `getExpensesByJudgeAndEvent()` - combined filter
  - `getExpensesByCategory()` - filter by expense category
  - `getExpensesByDateRange()` - date range with optional filters
- Calculation methods:
  - `getTotalExpensesByEvent()` - sum all expenses for event
  - `getTotalExpensesByJudge()` - sum all expenses for judge
  - `getTotalExpensesByAssignment()` - sum for assignment
  - `getTotalExpensesByCategory()` - sum by category
  - `getExpenseBreakdownByEvent()` - Map<ExpenseCategory, double> breakdown

### 3. Provider Layer ✅
**File**: `lib/providers/expense_provider.dart` (58 lines)
- 8 Riverpod providers for reactive state management:
  - `expensesByEventProvider` - FutureProvider.family<List<Expense>, String>
  - `expensesByJudgeProvider` - FutureProvider.family<List<Expense>, String>
  - `expensesByAssignmentProvider` - FutureProvider.family<List<Expense>, String>
  - `expensesByJudgeAndEventProvider` - FutureProvider.family with tuple parameter
  - `totalExpensesByEventProvider` - FutureProvider.family<double, String>
  - `totalExpensesByJudgeProvider` - FutureProvider.family<double, String>
  - `totalExpensesByAssignmentProvider` - FutureProvider.family<double, String>
  - `expenseBreakdownByEventProvider` - FutureProvider.family<Map<ExpenseCategory, double>, String>

### 4. UI Screens ✅

#### Expense List Screen
**File**: `lib/screens/expenses/expense_list_screen.dart` (389 lines)
- Displays expenses grouped by category or date (toggle view)
- Search functionality across descriptions and categories
- Filter dialog by expense category
- Total expenses summary badge at top
- ExpansionTiles for grouped expenses with category totals
- Receipt attachment indicator
- Navigation to detail screen on tap
- FAB to add new expense
- Supports filtering by event, judge, or assignment (query parameters)

#### Add/Edit Expense Screen
**File**: `lib/screens/expenses/add_edit_expense_screen.dart` (583 lines)
- Dynamic form based on selected category
- Category-specific fields:
  - **Mileage**: distance input, rate selection, auto-calculates total
  - **Meals**: meal type dropdown, per diem rate, auto-calculates
  - **Lodging**: check-in/out date pickers, auto-calculates nights
  - **Transportation**: type field (Uber, Lyft, Taxi, etc.)
- Receipt photo management:
  - Camera capture via ImagePicker
  - Gallery selection
  - Storage in app documents directory (`/receipts/`)
  - Preview with remove option
- Date picker for expense date
- Description field (optional)
- Amount field (manual override for auto-calculated values)
- Visual indicator for auto-calculated amounts (green icon)
- Form validation
- Provider invalidation on save (event, judge, assignment totals)

#### Expense Detail Screen
**File**: `lib/screens/expenses/expense_detail_screen.dart` (360 lines)
- Full expense details display
- Category icon and amount prominently displayed
- Auto-calculated indicator
- Description card (if provided)
- Category-specific details card (distance, rate, meal type, etc.)
- Receipt photo with tap-to-enlarge
- Full-screen image viewer with InteractiveViewer for zoom/pan
- Metadata: created/updated timestamps
- Edit and delete actions in app bar
- Confirmation dialog for deletion
- Provider invalidation after deletion

### 5. Integration ✅

#### Edit Assignment Screen Enhancement
**File**: `lib/screens/events/edit_assignment_screen.dart` (updated)
- Added expense summary section below role fees
- Shows total expenses in orange card
- Displays first 3 expenses with "View all" link if more
- "Add Expense" button with proper context (eventId, judgeId, assignmentId)
- Category icons and names for each expense
- Navigation to expense detail and list screens
- Reactive updates when expenses added/modified

#### Home Screen
**File**: `lib/screens/home_screen.dart` (updated)
- Added "Expenses" quick action card
- Icon: receipt_long
- Navigation to expense list screen

#### Routing
**File**: `lib/main.dart` (updated)
- `/expenses` - ExpenseListScreen with optional query params (eventId, judgeId, assignmentId)
- `/expenses/add` - AddEditExpenseScreen with extra context
- `/expenses/:id` - ExpenseDetailScreen
- `/expenses/:id/edit` - AddEditExpenseScreen for editing

## Key Features

### Auto-Calculation
- **Mileage**: distance × rate = amount
- **Meals**: per diem rate = amount
- **Lodging**: auto-calculates number of nights from check-in/out dates
- Visual indicator (green icon) when amount is auto-calculated
- Manual override capability (clears auto-calculated flag)

### Receipt Management
- Camera capture or gallery selection
- Stored in app documents directory: `/receipts/{uuid}.jpg`
- Image compression (maxWidth: 1920, maxHeight: 1080, quality: 85%)
- Preview in add/edit screen
- Full-screen viewer in detail screen with zoom/pan
- Receipt indicator in list view

### Grouping & Filtering
- Toggle between category and date grouping
- Search across descriptions and categories
- Category filter dialog
- Total calculations for each group
- Expense count display

### Provider Invalidation
- Smart invalidation when expenses created/updated/deleted
- Updates totals at all levels (event, judge, assignment)
- Reactive UI updates across all screens

## Database Schema
Expenses table already exists with all required fields:
```sql
CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  eventId TEXT NOT NULL,
  judgeId TEXT,
  sessionId TEXT,
  judgeAssignmentId TEXT,
  category TEXT NOT NULL,
  description TEXT,
  amount REAL NOT NULL,
  date TEXT NOT NULL,
  isAutoCalculated INTEGER NOT NULL DEFAULT 0,
  receiptPhotoPath TEXT,
  distance REAL,
  mileageRate REAL,
  mealType TEXT,
  perDiemRate REAL,
  transportationType TEXT,
  checkInDate TEXT,
  checkOutDate TEXT,
  numberOfNights INTEGER,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (judgeId) REFERENCES judges(id) ON DELETE SET NULL,
  FOREIGN KEY (sessionId) REFERENCES event_sessions(id) ON DELETE SET NULL,
  FOREIGN KEY (judgeAssignmentId) REFERENCES judge_assignments(id) ON DELETE SET NULL
)
```

## Financial Workflow
Phase 5 completes the core financial tracking workflow:

1. **Phase 4 (Fees)**: Judges earn fees for their work
   - Session rates (hourly × duration)
   - Role-based fees (Meet Referee, Head Judge)
   - Fee totals visible at all hierarchy levels

2. **Phase 5 (Expenses)**: Judges incur expenses during events
   - Travel: mileage, airfare, rental car, parking, tolls
   - Meals: breakfast, lunch, dinner, snacks with per diem
   - Lodging: hotel stays with check-in/out dates
   - Other: miscellaneous expenses
   - Receipt photo documentation

3. **Phase 6 (Next)**: Financial reporting
   - Net profit calculation (fees - expenses)
   - Export to PDF/CSV
   - Tax reporting data
   - Breakdown by event, judge, category
   - Year-end summaries

## Testing Checklist
- [ ] Create expense with mileage category (auto-calculation)
- [ ] Create expense with meals category (per diem)
- [ ] Create expense with lodging (date range calculation)
- [ ] Capture receipt photo with camera
- [ ] Select receipt from gallery
- [ ] View receipt in full-screen
- [ ] Edit existing expense
- [ ] Delete expense (with confirmation)
- [ ] Filter expenses by category
- [ ] Search expenses by description
- [ ] Toggle between category/date grouping
- [ ] View expenses from assignment detail
- [ ] Add expense from assignment detail
- [ ] Verify totals update reactively
- [ ] Test with multiple expenses across categories
- [ ] Verify expense persistence across app restarts

## Next Steps (Phase 6)

### Financial Reporting
1. Create reports screen with filters (date range, event, judge)
2. Generate PDF reports with fee/expense breakdown
3. CSV export functionality
4. Tax summary report (taxable vs non-taxable fees)
5. Year-end financial summary
6. Profit/loss calculation per event and per judge

### Enhanced Features (Phase 7)
1. Bulk expense import (CSV)
2. Recurring expenses (e.g., monthly parking pass)
3. Expense approval workflow
4. Budget tracking per event
5. Expense reimbursement status
6. Multi-currency support
7. Cloud sync/backup
8. Data visualization (charts, graphs)

## Files Created/Modified

### Created (6 files, 1,627 lines):
1. `lib/repositories/expense_repository.dart` - 237 lines
2. `lib/providers/expense_provider.dart` - 58 lines
3. `lib/screens/expenses/expense_list_screen.dart` - 389 lines
4. `lib/screens/expenses/add_edit_expense_screen.dart` - 583 lines
5. `lib/screens/expenses/expense_detail_screen.dart` - 360 lines

### Modified (4 files):
1. `lib/models/expense.dart` - Added judgeAssignmentId field
2. `lib/models/expense.g.dart` - Regenerated with build_runner
3. `lib/screens/events/edit_assignment_screen.dart` - Added expense summary section
4. `lib/screens/home_screen.dart` - Added Expenses quick action
5. `lib/main.dart` - Added 4 expense routes

## Code Quality
- ✅ Zero compilation errors
- ✅ Consistent naming conventions
- ✅ Proper null safety
- ✅ Comprehensive form validation
- ✅ Error handling with user feedback
- ✅ Loading states for async operations
- ✅ Provider invalidation patterns
- ✅ Reactive UI updates
- ✅ Proper disposal of controllers
- ✅ Navigation with proper context passing

## Summary
Phase 5 implementation is **100% complete** with all core expense tracking features. The system provides:
- Comprehensive expense tracking with 9 categories
- Smart auto-calculation for mileage, meals, and lodging
- Receipt photo management with camera/gallery integration
- Flexible grouping, filtering, and search
- Seamless integration with judge assignments
- Reactive state management with Riverpod
- Complete CRUD operations
- Professional UI with Material Design 3

Ready to proceed with Phase 6 (Financial Reporting) or any other enhancements!
