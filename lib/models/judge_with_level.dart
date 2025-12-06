import '../models/judge.dart';
import '../models/judge_level.dart';

/// Composite model that combines Judge with their certification levels
/// Since judges can have multiple certifications, this holds a list of levels
class JudgeWithLevels {
  final Judge judge;
  final List<JudgeLevel> levels;

  JudgeWithLevels({
    required this.judge,
    required this.levels,
  });

  String get id => judge.id;
  String get fullName => judge.fullName;
  String get firstName => judge.firstName;
  String get lastName => judge.lastName;
  String? get notes => judge.notes;
  String? get contactInfo => judge.contactInfo;
  
  // Get all associations this judge is certified in
  List<String> get associations => levels.map((l) => l.association).toSet().toList()..sort();
  
  // Get display string of all certifications
  String get certificationsDisplay {
    if (levels.isEmpty) return 'No certifications';
    return levels.map((l) => l.displayName).join(', ');
  }
  
  // Get levels for a specific association
  List<JudgeLevel> levelsFor(String association) {
    return levels.where((l) => l.association == association).toList();
  }
  
  // Check if judge has any certification in an association
  bool hasCertificationIn(String association) {
    return levels.any((l) => l.association == association);
  }
  
  // Get highest hourly rate across all certifications
  double get maxHourlyRate {
    if (levels.isEmpty) return 0.0;
    return levels.map((l) => l.defaultHourlyRate).reduce((a, b) => a > b ? a : b);
  }
}
