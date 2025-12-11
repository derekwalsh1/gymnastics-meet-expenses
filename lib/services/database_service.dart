import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nawgj_expense_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create judge_levels table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS judge_levels (
          id TEXT PRIMARY KEY,
          association TEXT NOT NULL,
          level TEXT NOT NULL,
          defaultHourlyRate REAL NOT NULL,
          sortOrder INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isArchived INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Insert default judge levels
      await _insertDefaultJudgeLevels(db);

      // Migrate judges table: SQLite doesn't support DROP COLUMN, so we need to recreate the table
      // First, get existing judge data
      final existingJudges = await db.query('judges');
      
      // Drop the old judges table
      await db.execute('DROP TABLE IF EXISTS judges');
      
      // Create new judges table with judgeLevelId
      await db.execute('''
        CREATE TABLE judges (
          id TEXT PRIMARY KEY,
          firstName TEXT NOT NULL,
          lastName TEXT NOT NULL,
          judgeLevelId TEXT NOT NULL,
          notes TEXT,
          contactInfo TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isArchived INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (judgeLevelId) REFERENCES judge_levels (id) ON DELETE RESTRICT
        )
      ''');
      
      // Migrate old judge data (if any exist)
      // Note: Old judges won't have judgeLevelId, so we'll skip them or assign a default
      // For now, we'll just skip old judges since we're transitioning to the new system
      
      // Create indexes for judge_levels and judges
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judge_levels_association ON judge_levels(association)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judge_levels_archived ON judge_levels(isArchived)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judges_levelId ON judges(judgeLevelId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judges_archived ON judges(isArchived)');
    }
    
    if (oldVersion < 3) {
      // Migration to version 3: Support for multiple judge levels per judge
      
      // Get existing judges with their judgeLevelId
      final existingJudges = await db.query('judges');
      
      // Drop the old judges table
      await db.execute('DROP TABLE IF EXISTS judges');
      
      // Create new judges table WITHOUT judgeLevelId (removed foreign key)
      await db.execute('''
        CREATE TABLE judges (
          id TEXT PRIMARY KEY,
          firstName TEXT NOT NULL,
          lastName TEXT NOT NULL,
          notes TEXT,
          contactInfo TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isArchived INTEGER NOT NULL DEFAULT 0
        )
      ''');
      
      // Create junction table for many-to-many relationship
      await db.execute('''
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
        )
      ''');
      
      // Restore judges and create certifications from old data
      for (final judge in existingJudges) {
        // Insert judge without judgeLevelId
        await db.insert('judges', {
          'id': judge['id'],
          'firstName': judge['firstName'],
          'lastName': judge['lastName'],
          'notes': judge['notes'],
          'contactInfo': judge['contactInfo'],
          'createdAt': judge['createdAt'],
          'updatedAt': judge['updatedAt'],
          'isArchived': judge['isArchived'],
        });
        
        // Create certification record for their original level
        final certId = '${judge['id']}_${judge['judgeLevelId']}';
        await db.insert('judge_certifications', {
          'id': certId,
          'judgeId': judge['id'],
          'judgeLevelId': judge['judgeLevelId'],
          'certificationDate': judge['createdAt'],
          'expirationDate': null,
          'createdAt': judge['createdAt'],
          'updatedAt': judge['updatedAt'],
        });
      }
      
      // Add Event association field
      await db.execute('''
        ALTER TABLE events ADD COLUMN associationId TEXT
      ''');
      
      // Create indexes
      await db.execute('DROP INDEX IF EXISTS idx_judges_levelId');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judge_certifications_judgeId ON judge_certifications(judgeId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_judge_certifications_levelId ON judge_certifications(judgeLevelId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_association ON events(associationId)');
    }
    
    if (oldVersion < 4) {
      // Migration to version 4: Complete event structure implementation
      
      // Drop old incomplete tables if they exist
      await db.execute('DROP TABLE IF EXISTS sessions');
      await db.execute('DROP TABLE IF EXISTS floors');
      await db.execute('DROP TABLE IF EXISTS floor_judge_assignments');
      await db.execute('DROP TABLE IF EXISTS event_days');
      await db.execute('DROP INDEX IF EXISTS idx_sessions_eventDayId');
      await db.execute('DROP INDEX IF EXISTS idx_floors_sessionId');
      await db.execute('DROP INDEX IF EXISTS idx_event_days_eventId');
      
      // Create event_days table
      await db.execute('''
        CREATE TABLE event_days (
          id TEXT PRIMARY KEY,
          eventId TEXT NOT NULL,
          dayNumber INTEGER NOT NULL,
          date TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE,
          UNIQUE(eventId, dayNumber)
        )
      ''');
      
      // Create event_sessions table
      await db.execute('''
        CREATE TABLE event_sessions (
          id TEXT PRIMARY KEY,
          eventDayId TEXT NOT NULL,
          sessionNumber INTEGER NOT NULL,
          name TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (eventDayId) REFERENCES event_days(id) ON DELETE CASCADE,
          UNIQUE(eventDayId, sessionNumber)
        )
      ''');
      
      // Create event_floors table
      await db.execute('''
        CREATE TABLE event_floors (
          id TEXT PRIMARY KEY,
          eventSessionId TEXT NOT NULL,
          floorNumber INTEGER NOT NULL,
          name TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (eventSessionId) REFERENCES event_sessions(id) ON DELETE CASCADE,
          UNIQUE(eventSessionId, floorNumber)
        )
      ''');
      
      // Create judge_assignments table
      await db.execute('''
        CREATE TABLE judge_assignments (
          id TEXT PRIMARY KEY,
          eventFloorId TEXT NOT NULL,
          judgeId TEXT NOT NULL,
          judgeFirstName TEXT NOT NULL,
          judgeLastName TEXT NOT NULL,
          judgeAssociation TEXT NOT NULL,
          judgeLevel TEXT NOT NULL,
          judgeContactInfo TEXT,
          role TEXT,
          hourlyRate REAL NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (eventFloorId) REFERENCES event_floors(id) ON DELETE CASCADE
        )
      ''');
      
      // Create judge_fees table
      await db.execute('''
        CREATE TABLE judge_fees (
          id TEXT PRIMARY KEY,
          judgeAssignmentId TEXT NOT NULL,
          feeType TEXT NOT NULL,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          hours REAL,
          isAutoCalculated INTEGER NOT NULL,
          isTaxable INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          FOREIGN KEY (judgeAssignmentId) REFERENCES judge_assignments(id) ON DELETE CASCADE
        )
      ''');
      
      // Extend expenses table
      await db.execute('ALTER TABLE expenses ADD COLUMN judgeAssignmentId TEXT');
      
      // Create indexes
      await db.execute('CREATE INDEX idx_event_days_eventId ON event_days(eventId)');
      await db.execute('CREATE INDEX idx_event_sessions_eventDayId ON event_sessions(eventDayId)');
      await db.execute('CREATE INDEX idx_event_floors_eventSessionId ON event_floors(eventSessionId)');
      await db.execute('CREATE INDEX idx_judge_assignments_eventFloorId ON judge_assignments(eventFloorId)');
      await db.execute('CREATE INDEX idx_judge_assignments_judgeId ON judge_assignments(judgeId)');
      await db.execute('CREATE INDEX idx_judge_fees_judgeAssignmentId ON judge_fees(judgeAssignmentId)');
      await db.execute('CREATE INDEX idx_expenses_judgeAssignmentId ON expenses(judgeAssignmentId)');
    }

    if (oldVersion < 5) {
      // Migration to version 5: apparatus per assignment
      await db.execute('ALTER TABLE judge_assignments ADD COLUMN apparatus TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Judge Levels table
    await db.execute('''
      CREATE TABLE judge_levels (
        id TEXT PRIMARY KEY,
        association TEXT NOT NULL,
        level TEXT NOT NULL,
        defaultHourlyRate REAL NOT NULL,
        sortOrder INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Judges table (version 3: removed judgeLevelId)
    await db.execute('''
      CREATE TABLE judges (
        id TEXT PRIMARY KEY,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        notes TEXT,
        contactInfo TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    // Judge Certifications junction table (version 3: many-to-many)
    await db.execute('''
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
      )
    ''');
    
    // Insert default judge levels
    await _insertDefaultJudgeLevels(db);

    // Events table (version 3: added associationId)
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        locationVenueName TEXT NOT NULL,
        locationAddress TEXT NOT NULL,
        locationCity TEXT NOT NULL,
        locationState TEXT NOT NULL,
        locationZipCode TEXT NOT NULL,
        description TEXT NOT NULL,
        totalBudget REAL,
        status TEXT NOT NULL,
        associationId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Event Days table (version 4)
    await db.execute('''
      CREATE TABLE event_days (
        id TEXT PRIMARY KEY,
        eventId TEXT NOT NULL,
        dayNumber INTEGER NOT NULL,
        date TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE,
        UNIQUE(eventId, dayNumber)
      )
    ''');

    // Event Sessions table (version 4)
    await db.execute('''
      CREATE TABLE event_sessions (
        id TEXT PRIMARY KEY,
        eventDayId TEXT NOT NULL,
        sessionNumber INTEGER NOT NULL,
        name TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (eventDayId) REFERENCES event_days(id) ON DELETE CASCADE,
        UNIQUE(eventDayId, sessionNumber)
      )
    ''');

    // Event Floors table (version 4)
    await db.execute('''
      CREATE TABLE event_floors (
        id TEXT PRIMARY KEY,
        eventSessionId TEXT NOT NULL,
        floorNumber INTEGER NOT NULL,
        name TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (eventSessionId) REFERENCES event_sessions(id) ON DELETE CASCADE,
        UNIQUE(eventSessionId, floorNumber)
      )
    ''');

    // Judge Assignments table (version 5: added apparatus)
    await db.execute('''
      CREATE TABLE judge_assignments (
        id TEXT PRIMARY KEY,
        eventFloorId TEXT NOT NULL,
        apparatus TEXT,
        judgeId TEXT NOT NULL,
        judgeFirstName TEXT NOT NULL,
        judgeLastName TEXT NOT NULL,
        judgeAssociation TEXT NOT NULL,
        judgeLevel TEXT NOT NULL,
        judgeContactInfo TEXT,
        role TEXT,
        hourlyRate REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (eventFloorId) REFERENCES event_floors(id) ON DELETE CASCADE
      )
    ''');

    // Judge Fees table (version 4)
    await db.execute('''
      CREATE TABLE judge_fees (
        id TEXT PRIMARY KEY,
        judgeAssignmentId TEXT NOT NULL,
        feeType TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        hours REAL,
        isAutoCalculated INTEGER NOT NULL,
        isTaxable INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (judgeAssignmentId) REFERENCES judge_assignments(id) ON DELETE CASCADE
      )
    ''');

    // Expenses table (version 4: added judgeAssignmentId)
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        eventId TEXT NOT NULL,
        judgeId TEXT,
        sessionId TEXT,
        judgeAssignmentId TEXT,
        category TEXT NOT NULL,
        distance REAL,
        mileageRate REAL,
        mealType TEXT,
        perDiemRate REAL,
        transportationType TEXT,
        checkInDate TEXT,
        checkOutDate TEXT,
        numberOfNights INTEGER,
        amount REAL NOT NULL,
        isAutoCalculated INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        receiptPhotoPath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (eventId) REFERENCES events(id) ON DELETE CASCADE,
        FOREIGN KEY (judgeId) REFERENCES judges(id) ON DELETE SET NULL,
        FOREIGN KEY (judgeAssignmentId) REFERENCES judge_assignments(id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_judge_levels_association ON judge_levels(association)');
    await db.execute('CREATE INDEX idx_judge_levels_archived ON judge_levels(isArchived)');
    await db.execute('CREATE INDEX idx_judges_archived ON judges(isArchived)');
    await db.execute('CREATE INDEX idx_judge_certifications_judgeId ON judge_certifications(judgeId)');
    await db.execute('CREATE INDEX idx_judge_certifications_levelId ON judge_certifications(judgeLevelId)');
    await db.execute('CREATE INDEX idx_events_status ON events(status)');
    await db.execute('CREATE INDEX idx_events_dates ON events(startDate, endDate)');
    await db.execute('CREATE INDEX idx_events_association ON events(associationId)');
    await db.execute('CREATE INDEX idx_event_days_eventId ON event_days(eventId)');
    await db.execute('CREATE INDEX idx_event_sessions_eventDayId ON event_sessions(eventDayId)');
    await db.execute('CREATE INDEX idx_event_floors_eventSessionId ON event_floors(eventSessionId)');
    await db.execute('CREATE INDEX idx_judge_assignments_eventFloorId ON judge_assignments(eventFloorId)');
    await db.execute('CREATE INDEX idx_judge_assignments_judgeId ON judge_assignments(judgeId)');
    await db.execute('CREATE INDEX idx_judge_fees_judgeAssignmentId ON judge_fees(judgeAssignmentId)');
    await db.execute('CREATE INDEX idx_expenses_eventId ON expenses(eventId)');
    await db.execute('CREATE INDEX idx_expenses_judgeId ON expenses(judgeId)');
    await db.execute('CREATE INDEX idx_expenses_judgeAssignmentId ON expenses(judgeAssignmentId)');
  }

  Future<void> _insertDefaultJudgeLevels(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    final defaultLevels = [
      // NAWGJ levels
      {'association': 'NAWGJ', 'level': '4-5', 'rate': 20.0, 'order': 1},
      {'association': 'NAWGJ', 'level': '6-8', 'rate': 25.0, 'order': 2},
      {'association': 'NAWGJ', 'level': 'Nine', 'rate': 30.0, 'order': 3},
      {'association': 'NAWGJ', 'level': 'Ten', 'rate': 35.0, 'order': 4},
      {'association': 'NAWGJ', 'level': 'Brevet', 'rate': 40.0, 'order': 5},
      {'association': 'NAWGJ', 'level': 'National', 'rate': 50.0, 'order': 6},
      // NGA levels
      {'association': 'NGA', 'level': 'Local', 'rate': 15.0, 'order': 7},
      {'association': 'NGA', 'level': 'State', 'rate': 20.0, 'order': 8},
      {'association': 'NGA', 'level': 'Regional', 'rate': 25.0, 'order': 9},
      {'association': 'NGA', 'level': 'National', 'rate': 35.0, 'order': 10},
      {'association': 'NGA', 'level': 'Elite', 'rate': 45.0, 'order': 11},
    ];

    for (final level in defaultLevels) {
      await db.insert('judge_levels', {
        'id': '${level['association']}-${level['level']}'.replaceAll(' ', '-'),
        'association': level['association'],
        'level': level['level'],
        'defaultHourlyRate': level['rate'],
        'sortOrder': level['order'],
        'createdAt': now,
        'updatedAt': now,
        'isArchived': 0,
      });
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
