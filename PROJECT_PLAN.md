# Gymnastics Judges Expense Management App - Project Plan

## Project Overview
**App Name:** Gymnastics Judging Expense Tracker
**Platform:** Cross-platform (iOS & Android)
**Technology:** Flutter
**Target Users:** Meet managers (judges organizing meets) who create expense reports for event organizers
**Data Storage:** Local-first architecture with import/export capabilities

## Purpose
Enable meet managers to create and manage gymnastics meet expense reports that will be submitted to event organizers for reimbursement. The app focuses on event setup (location, dates, sessions, floors) and judge assignment tracking, with all data stored locally on the device.

---

## User Roles & Permissions

### Meet Manager (Single User - Local App)
- **Judge Database Management**
  - Create/edit/delete judge profiles
  - Store judge information (name, association, level)
  - Import judge lists from other users
  - Export judge lists (full or filtered subsets)
  
- **Event Management (CRUD)**
  - Create new gymnastics meets/events
  - Define event details (location, date, description)
  - Set up event structure:
    - Event days
    - Sessions per day
    - Floors per session
  - Assign judges to specific floors
  - Read/view all events
  - Update event details
  - Delete events
  
- **Expense Report Generation**
  - Create comprehensive expense reports per event
  - Calculate totals by judge, floor, session, or event
  - Export reports for submission to event organizers
  - Generate PDF/CSV formats for reimbursement requests

---

## Core Features

### A. Judge Database Management (Local)
- **Add Judge**
  - Name (first and last)
  - Judging association (e.g., NAWGJ, AAU, etc.)
  - Level within association (e.g., Level 1-10, Brevet)
  - Hourly rate (for automatic fee calculations)
  - Optional notes/contact info
  
- **Edit Judge**
  - Update any judge information
  - Maintain assignment history
  
- **Delete Judge**
  - Confirmation dialog
  - Option to archive (soft delete) if assigned to events
  
- **Search & Filter**
  - Search by name
  - Filter by association
  - Filter by level
  - Sort alphabetically or by most used
  
- **Import/Export Judges**
  - Export full judge list (JSON/CSV)
  - Export filtered subset
  - Import judge list from file
  - Merge imported judges with existing (avoid duplicates)
  - Share via email, AirDrop, or file sharing

### B. Event Management

- **Create Event**
  - Event name
  - Date(s) - start and end
  - Location (venue name, address, city, state)
  - Event description/notes
  - Event structure:
    - Number of event days
    - Sessions per day (e.g., Morning, Afternoon, Evening)
    - Floors per session (e.g., Vault, Bars, Beam, Floor)
  - Assign judges to specific floors
  - Budget/expense tracking per event
  
- **View Events**
  - List view with filters (upcoming, past, by date range)
  - Calendar view option
  - Search functionality
  - Event details view showing:
    - Event info
    - Full schedule (days → sessions → floors)
    - Judge assignments
    - Expense summary
  
- **Update Event**
  - Edit all event details
  - Modify event structure (add/remove days, sessions, floors)
  - Reassign judges
  - Update expenses
  
- **Delete Event**
  - Confirmation dialog
  - Archive option (soft delete)
  - Preserve historical data

### C. Floor & Judge Assignment

- **Session/Floor Setup**
  - Define session times
  - Name floors (e.g., "Floor 1 - Level 7", "Vault 2")
  - Set number of judges needed per floor
  
- **Judge Assignment**
  - Drag-and-drop interface or picker
  - Select from local judge database
  - Assign multiple judges to same floor
  - Visual indication of judge availability
  - Copy assignments between sessions
  - Quick templates for common setups

### D. Expense Management

- **Track Event Expenses**
  - Expense categories:
    - Judge fees/stipends (auto-calculated from hourly rate × session duration)
    - Mileage (with distance and rate per mile)
    - Meals/Per Diem (breakfast, lunch, dinner, or daily rate)
    - Tolls
    - Airfare
    - Transportation (rental car, taxi, rideshare, etc.)
    - Parking
    - Lodging (hotel/accommodation)
    - Other expenses (miscellaneous with description)
  - Add expenses at event, session, or judge level
  - Auto-calculate judge fees based on assigned sessions and hourly rates
  - Auto-calculate mileage (distance × mileage rate)
  - Manual override option for calculated fees
  - Attach notes and descriptions
  - Optional receipt photos (stored locally)
  
- **Calculate Totals**
  - Total by judge (including auto-calculated fees from all sessions)
  - Total by session
  - Total by day
  - Total by expense category
  - Grand total for event
  - Breakdown of calculated fees vs. manual expenses
  - Summary of judge hours worked

### E. Reporting & Export

- **Generate Reports**
  - Event summary report
  - Judge assignment report (schedule)
  - Expense breakdown report
  - Custom date ranges
  - Filter by specific criteria
  
- **Export Options**
  - PDF for professional submission
  - CSV/Excel for data manipulation
  - Print-friendly format
  - Email directly from app
  - Share via AirDrop/file sharing
  
- **Report Templates**
  - Customizable headers (organization name, logo)
  - Standard reimbursement format
  - Save report templates for reuse

### F. Data Management

- **Backup & Restore**
  - Local backup to device storage
  - Export full app data
  - Import/restore from backup
  - Cloud backup option (iCloud/Google Drive) - optional
  
- **Data Privacy**
  - All data stored locally on device
  - No remote servers or accounts required
  - User controls all data sharing
  - Clear data option (factory reset)

---

## Technical Architecture

### 1. Frontend (Flutter)
- **State Management:** Riverpod or Bloc
- **Navigation:** Go Router
- **Local Database:** 
  - SQLite (via sqflite package) for structured data
  - Hive or Isar for fast key-value storage
- **File Storage:**
  - Local file system for receipts and exports
  - path_provider for platform-specific directories
- **UI Components:**
  - Material Design 3
  - Custom theme for professional appearance
  - Responsive layouts (phone & tablet support)
  - Drag-and-drop for judge assignments

### 2. Backend/Data Storage
**Local-First Architecture (No Remote Server Required)**
- All data stored locally on device
- SQLite database for relational data
- File system for documents and images
- No authentication needed
- No internet connection required for core functionality

**Optional Cloud Features:**
- iCloud/Google Drive backup (user-controlled)
- File sharing via platform APIs
- No proprietary backend services

### 3. Data Models

#### Judge
```dart
{
  id: string (UUID),
  firstName: string,
  lastName: string,
  association: string, // e.g., "NAWGJ", "AAU", "FIG"
  level: string, // e.g., "Level 7-10", "Brevet 1"
  hourlyRate: number, // hourly compensation rate
  notes: string (optional),
  contactInfo: string (optional),
  createdAt: timestamp,
  updatedAt: timestamp,
  isArchived: boolean
}
```

#### Event
```dart
{
  id: string (UUID),
  name: string,
  startDate: timestamp,
  endDate: timestamp,
  location: {
    venueName: string,
    address: string,
    city: string,
    state: string,
    zipCode: string
  },
  description: string,
  eventDays: [EventDay],
  totalBudget: number (optional),
  status: enum[upcoming, ongoing, completed, archived],
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### EventDay
```dart
{
  id: string (UUID),
  eventId: string,
  dayNumber: int, // 1, 2, 3, etc.
  date: timestamp,
  sessions: [Session]
}
```

#### Session
```dart
{
  id: string (UUID),
  eventDayId: string,
  name: string, // e.g., "Morning Session", "Session 1"
  startTime: time,
  endTime: time,
  durationHours: number, // calculated or manual, used for fee calculations
  floors: [Floor]
}
```

#### Floor
```dart
{
  id: string (UUID),
  sessionId: string,
  name: string, // e.g., "Vault 1", "Floor Exercise - Level 7"
  apparatus: string, // vault, bars, beam, floor
  assignedJudges: [judgeId],
  notes: string (optional)
}
```

#### Expense
```dart
{
  id: string (UUID),
  eventId: string,
  judgeId: string (optional), // null if event-level expense
  sessionId: string (optional), // null if not session-specific
  category: enum[judge_fees, mileage, meals_per_diem, tolls, airfare, transportation, parking, lodging, other],
  
  // Category-specific fields
  // For mileage:
  distance: number (optional), // miles driven
  mileageRate: number (optional), // rate per mile (e.g., IRS standard)
  
  // For meals/per diem:
  mealType: enum[breakfast, lunch, dinner, full_day] (optional),
  perDiemRate: number (optional),
  
  // For transportation:
  transportationType: string (optional), // rental_car, taxi, rideshare, etc.
  
  // For lodging:
  checkInDate: timestamp (optional),
  checkOutDate: timestamp (optional),
  numberOfNights: number (optional),
  
  // Common fields
  amount: number, // calculated or manual
  isAutoCalculated: boolean, // true for mileage, judge fees
  date: timestamp,
  description: string,
  receiptPhotoPath: string (optional, local file path),
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### ImportExportFormat (for judge sharing)
```dart
{
  version: string, // format version for compatibility
  exportDate: timestamp,
  judges: [Judge],
  metadata: {
    appVersion: string,
    exportedBy: string (optional)
  }
}
```

---

## UI/UX Design

### Screen Flow

#### Main App Flow
1. **Home Dashboard**
   - Upcoming events (card view)
   - Recent events
   - Quick actions:
     - Create new event
     - Manage judges
     - View all events
   - Statistics overview (total events, judges in database)
   
2. **Judge Database Screen**
   - List of all judges (searchable, filterable)
   - Display judge cards showing name, association, level, and hourly rate
   - Add judge button (FAB)
   - Judge detail view (tap to edit)
   - Bulk actions:
     - Export all
     - Export filtered
     - Import judges
   - Sort options (name, association, level, hourly rate, most used)
   
3. **Event List Screen**
   - All events with status indicators
   - Filter by date, status
   - Search by name or location
   - Tap to view event details
   
4. **Event Details Screen**
   - Event information section
   - Days/Sessions/Floors hierarchy (expandable)
   - Judge assignments (visual grid or list)
   - Expenses summary
   - Actions:
     - Edit event
     - Add expenses
     - Generate report
     - Duplicate event
     - Delete/archive
   
5. **Create/Edit Event Screen**
   - Multi-step wizard:
     - Step 1: Basic info (name, dates, location)
     - Step 2: Event structure (days, sessions, floors)
     - Step 3: Judge assignments
     - Step 4: Review and save
   - Save as draft option
   
6. **Judge Assignment Screen**
   - Visual floor layout
   - Available judges list
   - Assigned judges per floor
   - Drag-and-drop or tap to assign
   - Copy assignments to other sessions
   - Templates for quick setup
   
7. **Expenses Screen**
   - Expense list for selected event
   - Auto-calculated judge fees section (expandable to see breakdown)
   - Manual expenses section
   - Add expense button
   - Filter by category, judge, session
   - Running total display (calculated + manual)
   - "Recalculate Fees" button (updates based on current assignments/rates)
   - Quick add common expenses
   
8. **Reports Screen**
   - Select report type:
     - Full event report
     - Judge assignment schedule
     - Expense breakdown
     - Custom report
   - Preview report
   - Export/share options
   - Print option
   
9. **Settings Screen**
   - App preferences:
     - Default currency
     - Default mileage rate (e.g., IRS standard rate)
     - Default per diem rates (breakfast, lunch, dinner, full day)
     - Default expense categories
     - Date/time format
     - Theme (light/dark)
   - Data management:
     - Backup app data
     - Restore from backup
     - Export all data
     - Clear all data
   - Import/Export:
     - Judge database import/export
     - Event templates
   - About/help

### Design Principles
- **Offline-First:** All features work without internet
- **Clean Interface:** Professional, uncluttered design
- **Easy Navigation:** Bottom navigation bar for main sections
- **Floating Action Buttons:** Quick access to primary actions
- **Consistent Color Scheme:** Professional blue/gray palette
- **Clear Visual Hierarchy:** Important information stands out
- **Efficient Workflows:** Minimize taps to complete tasks
- **Accessibility:** Support for screen readers, large text, high contrast

### Key UI Components
- **Cards:** Event and judge display
- **Expansion Panels:** Hierarchical event structure
- **Date Pickers:** Calendar-style date selection
- **Drag-and-Drop:** Judge assignment interface
- **Data Tables:** Expense lists, reports
- **Charts:** Visual expense breakdowns (pie/bar charts)
- **FABs:** Add judge, add event, add expense
- **Bottom Sheets:** Quick actions and filters
- **Dialogs:** Confirmations, quick edits

---

## Security & Privacy

### Data Protection
- **Local-Only Storage:** All data remains on user's device
- **No Remote Servers:** No data transmitted to external servers
- **File Encryption:** Option to encrypt local database with device security
- **Secure File Sharing:** Use platform-native secure sharing mechanisms

### Privacy
- **No User Tracking:** No analytics or telemetry without explicit opt-in
- **No Accounts Required:** No personal information collected
- **User Data Control:** Users own and control all their data
- **Clear Data Policy:** Transparent about what data is stored and where
- **Easy Data Export:** Users can export all data at any time

### Access Control
- **Device Security:** Relies on device lock screen/biometrics
- **Optional App Lock:** PIN or biometric lock for app access
- **Data Isolation:** App data stored in sandboxed app directory

---

## Development Phases

### Phase 1: MVP (Minimum Viable Product)
**Timeline: 6-8 weeks**

**Features:**
- Local SQLite database setup
- Judge database (CRUD operations)
- Basic event creation with simple structure
- Single-day events with sessions and floors
- Basic judge assignment (manual selection)
- Simple expense tracking
- Basic list views
- Local data persistence

**Deliverables:**
- Functional iOS and Android apps
- Local database schema
- Basic UI with core functionality
- Judge import/export (JSON)

### Phase 2: Enhanced Event Management
**Timeline: 3-4 weeks**

**Features:**
- Multi-day event support
- Complete event structure (days → sessions → floors)
- Advanced judge assignment interface (drag-and-drop)
- Judge filtering and search
- Event templates for quick setup
- Copy/paste sessions and assignments
- Enhanced expense categories
- Receipt photo capture and storage

### Phase 3: Reporting & Export
**Timeline: 3-4 weeks**

**Features:**
- Report generation (PDF/CSV)
- Customizable report templates
- Expense calculations and summaries
- Visual charts and graphs
- Email/share functionality
- Print support
- Data backup and restore
- Full app data export

### Phase 4: Polish & Optimization
**Timeline: 2-3 weeks**

**Features:**
- Performance optimization
- UI/UX refinements based on testing
- Tablet-optimized layouts
- Accessibility improvements
- Dark mode
- App icon and splash screen
- Tutorial/onboarding
- Help documentation
- Bug fixes and testing

---

## Testing Strategy

### Unit Testing
- Business logic
- Data models
- Utilities

### Integration Testing
- API calls
- Database operations
- Authentication flow

### Widget Testing
- UI components
- Form validation
- Navigation

### End-to-End Testing
- Complete user flows
- Critical paths

### User Acceptance Testing
- Beta testing with real judges
- Feedback collection
- Iterative improvements

---

## Deployment

### App Store Requirements
- **Apple App Store**
  - Developer account ($99/year)
  - App Store guidelines compliance
  - Privacy policy
  - Screenshots and descriptions
  
- **Google Play Store**
  - Developer account ($25 one-time)
  - Play Store guidelines compliance
  - Privacy policy
  - Screenshots and descriptions

### CI/CD Pipeline
- GitHub Actions or Fastlane
- Automated builds
- Automated testing
- Beta distribution (TestFlight, Firebase App Distribution)

---

## Success Metrics

### User Engagement
- Daily/monthly active users
- Expense submission rate
- Average session duration
- Feature usage statistics

### Performance
- App load time < 3 seconds
- Expense submission completion rate > 90%
- Crash-free rate > 99%
- Response time for API calls < 500ms

### Business Goals
- Number of events created per month
- Number of expenses tracked
- User satisfaction score > 4.5/5
- Approval workflow efficiency

---

## Future Enhancements (Post-Launch)

### Advanced Features
- **Cloud Sync (Optional):** 
  - iCloud/Google Drive sync for multi-device access
  - Encrypted cloud backup
  - Conflict resolution for concurrent edits
  
- **Enhanced Judge Management:**
  - Judge availability calendar
  - Travel distance calculations
  - Judge preferences and specialties
  - Historical assignment tracking
  
- **Advanced Reporting:**
  - Comparative reports across events
  - Year-end summaries
  - Trend analysis
  - Customizable report builder
  
- **Automation:**
  - Auto-calculate fees based on rules
  - Mileage calculator with Google Maps integration for distance
  - GPS tracking for automatic mileage logging
  - Smart judge suggestions based on history
  - Bulk operations (mass assign judges)
  - Event duplication with modifications
  - Auto-populate per diem based on event days
  
- **Templates & Presets:**
  - Save event structures as templates
  - Default fee structures by event type
  - Quick-fill for common scenarios
  
- **Enhanced Export:**
  - Direct integration with accounting software
  - QuickBooks/Excel formatted exports
  - Customizable CSV formats
  - Batch export multiple events

### Integration Possibilities
- Calendar apps (add events to device calendar)
- Email (auto-send reports to event organizers)
- Contacts (import judges from device contacts)
- Cloud storage providers (more backup options)

---

## Risk Assessment & Mitigation

### Technical Risks
- **Risk:** Data loss due to device failure or app deletion
  - **Mitigation:** Implement automatic local backups, easy export functionality, remind users to backup regularly
  
- **Risk:** Database corruption
  - **Mitigation:** Regular integrity checks, automatic backups before major operations, recovery mechanisms
  
- **Risk:** Performance issues with large datasets
  - **Mitigation:** Efficient database indexing, pagination for large lists, lazy loading, data archiving

### Business Risks
- **Risk:** Low user adoption
  - **Mitigation:** User testing during development, intuitive design, tutorial on first launch
  
- **Risk:** Users prefer cloud-synced solutions
  - **Mitigation:** Add optional cloud backup in Phase 2+, market privacy/simplicity as advantages

### Data Risks
- **Risk:** Users accidentally delete important data
  - **Mitigation:** Confirmation dialogs, soft deletes with recovery option, automatic backups
  
- **Risk:** Judge list sharing creates duplicate entries
  - **Mitigation:** Smart duplicate detection during import, merge suggestions, clear import preview

---

## Budget Estimation (Rough)

### Development Costs
- Developer time (assuming solo or small team): 14-19 weeks total
- Design resources: UI/UX design work (can use Flutter's built-in Material Design)
- Testing devices: iOS and Android devices (or use simulators/emulators)

### Operational Costs (One-Time & Annual)
- Apple Developer Account: $99/year (required for App Store)
- Google Play Developer Account: $25 one-time (required for Play Store)
- **No ongoing backend costs** (local-only app)
- Domain name (optional): $10-15/year (for landing page/support site)

### Maintenance
- Ongoing development: Feature updates, bug fixes
- Support: User support (email/documentation)
- OS updates: Keep compatible with new iOS/Android versions

**Total First Year Estimate:** $124 + development time
**Annual Recurring:** $99-114 (just app store fees)

**Significant Cost Savings vs. Cloud-Based:**
- No Firebase/AWS fees
- No database hosting costs
- No authentication service costs
- No cloud storage costs
- No bandwidth/API call charges

---

## Next Steps

1. **Review & Refine Plan**
   - Review this updated plan
   - Confirm feature priorities
   - Finalize MVP scope
   - Decide on optional features

2. **Technical Setup**
   - Create Flutter project structure
   - Set up SQLite database schema
   - Configure development environment
   - Set up version control (Git)
   - Create GitHub repository

3. **Design Phase**
   - Create wireframes for key screens
   - Define color scheme and typography
   - Create app icon
   - Design judge assignment interface
   - Plan event structure UI

4. **Development Kickoff**
   - Set up project management (optional)
   - Implement database layer
   - Build judge database features
   - Create event management UI
   - Begin Phase 1 development

---

## Questions to Consider

Before starting development, consider these questions:

1. **Judge Assignment:** Should judges be assignable to multiple floors in the same session, or is one floor per session sufficient?

2. **Expense Calculations:** 
   - Should mileage calculations use a default rate (e.g., IRS standard $0.67/mile) or custom per judge?
   - Should per diem be calculated automatically based on event days or entered manually?
   - Do you track meals as individual items or use a daily per diem rate?

3. **Judge Information:** What additional judge information would be helpful (certifications, specialties, availability, home address for mileage calculations)?

3. **Event Templates:** Would you benefit from saving event structures as templates (e.g., "Standard Level 7-10 Meet")?

4. **Rate Variations:** Do judges ever have different rates for different types of sessions or events (e.g., higher rate for championships)? Should the hourly rate be overridable per event?

5. **Session Duration:** Should session duration be manually entered or auto-calculated from start/end times?

6. **Receipt Management:** Are receipt photos necessary, or is amount/description sufficient?

6. **Report Formats:** What specific format do event organizers typically require for reimbursement submissions?

7. **Judge Sharing:** How commonly will users need to share judge lists? Should this be a primary or secondary feature?

8. **Data Migration:** Any existing data (spreadsheets, documents) that should be importable?

9. **Rounding Rules:** How should hourly calculations be rounded (e.g., if a session is 3.5 hours at $40/hr = $140)?

10. **Multi-Device:** Do you need the same data accessible on multiple devices (e.g., iPhone and iPad)?

---

## Conclusion

This plan provides a comprehensive roadmap for developing a local-first, cross-platform gymnastics meet expense management application. The simplified architecture (no authentication, no backend servers) significantly reduces complexity while maintaining full functionality for meet managers.

**Key Advantages of This Approach:**
- **No ongoing costs** beyond app store fees
- **Complete data privacy** - all data stays on device
- **Works offline** - no internet required
- **Faster development** - no backend to build or maintain
- **Simpler security** - no user accounts or servers to secure
- **Easy data sharing** - import/export judge lists between users

**Recommended Starting Point:** Phase 1 MVP with local SQLite database, focusing on judge database management and basic event creation with expense tracking.

**Total Development Timeline:** 14-19 weeks to full release

