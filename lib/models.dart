import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

// -------------------------------------------------------------------
// --- 1. Dynamic Categories and Data Models ---
// -------------------------------------------------------------------

// define dynamic Category class
class Category {
  // class variables
  final String id; // unique category id
  final String name; // category display name
  final String iconName; // icon name from https://fonts.google.com/icons
  final String colorHex; // color in hexadecimal format '0xAARRGGBB'
  final int? defaultDosage; // default dosage in mg, only for medication types

  Category({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.defaultDosage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconName': iconName,
    'colorHex': colorHex,
    'defaultDosage': defaultDosage,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'],
    name: json['name'],
    iconName: json['iconName'],
    colorHex: json['colorHex'],
    defaultDosage: json['defaultDosage'],
  );

  // get Icon from iconName
  IconData get icon {
    switch (iconName) {
      case 'work_outline': return Icons.work_outline;
      case 'self_improvement_outlined': return Icons.self_improvement_outlined;
      case 'explore_outlined': return Icons.explore_outlined;
      case 'people_outline': return Icons.people_outline;
      case 'bed': return Icons.bed;
      case 'weekend': return Icons.weekend;
      case 'directions_car': return Icons.directions_car;
      case 'medication': return Icons.medication;
      case 'directions_walk': return Icons.directions_walk;
      case 'directions_run': return Icons.directions_run;
      case 'fitness_center': return Icons.fitness_center;
      case 'coffee': return Icons.coffee;
      case 'emoji_food_beverage': return Icons.emoji_food_beverage;
      case 'local_drink': return Icons.local_drink;
      case 'wine_bar': return Icons.wine_bar;
      default: return Icons.wb_sunny_outlined;
    }
  }

  Color get color {
    try {
      var intColor = int.tryParse(colorHex);
      if (intColor == null) {
        return const Color.fromARGB(255, 158, 158, 158); 
      }
      else {
        return Color(intColor);
      }
    } catch (e) {
      return const Color.fromARGB(255, 158, 158, 158); 
    }
  }

  MaterialColor get materialColor {
    try {
      var intColor = int.tryParse(colorHex);
      if (intColor == null) {
        return Colors.grey; 
      }
      else {
        return MaterialColor(intColor, <int, Color>{
          50: Color(intColor).withAlpha(30),
          100: Color(intColor).withAlpha(55),
          200: Color(intColor).withAlpha(80),
          300: Color(intColor).withAlpha(105),
          400: Color(intColor).withAlpha(130),
          500: Color(intColor).withAlpha(155),
          600: Color(intColor).withAlpha(180),
          700: Color(intColor).withAlpha(205),
          800: Color(intColor).withAlpha(230),
          900: Color(intColor).withAlpha(255),
        });
      }
    } catch (e) {
      return Colors.grey; 
    }
  }
  String get displayName => name;
}

class CategoryManager {
  static final CategoryManager _instance = CategoryManager._internal();
  factory CategoryManager() => _instance;
  CategoryManager._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _initializeDefaultCategories();
    
    // Force migration to new 2-option substance list if detected old version
    final substances = await getCategories('substance_types');
    if (substances.any((c) => c.id == 'tea' || c.id == 'cola')) {
       final newSubstanceTypes = [
        Category(id: 'caffeine', name: 'Caffeine', iconName: 'coffee', colorHex: '0xFF795548'),
        Category(id: 'alcohol', name: 'Alcohol', iconName: 'wine_bar', colorHex: '0xFF9C27B0'),
      ];
      await saveCategories('substance_types', newSubstanceTypes);
    }
  }

  Future<void> _initializeDefaultCategories() async {
    // Day Types
    if (_prefs.getString('day_types') == null) {
      final defaultDayTypes = [
        Category(id: 'work', name: 'Work', iconName: 'work_outline', colorHex: '0xFF1565C0'),
        Category(id: 'relax', name: 'Relax', iconName: 'self_improvement_outlined', colorHex: '0xFF2E7D32'),
        Category(id: 'travel', name: 'Travel', iconName: 'explore_outlined', colorHex: '0xFFEF6C00'),
        Category(id: 'social', name: 'Social', iconName: 'people_outline', colorHex: '0xFF7B1FA2'),
      ];
      await saveCategories('day_types', defaultDayTypes);
    }

    // Sleep Locations
    if (_prefs.getString('sleep_locations') == null) {
      final defaultSleepLocations = [
        Category(id: 'bed', name: 'Bed', iconName: 'bed', colorHex: '0xFF1565C0'),
        Category(id: 'couch', name: 'Couch', iconName: 'weekend', colorHex: '0xFF2E7D32'),
        Category(id: 'in_transit', name: 'In Transit', iconName: 'directions_car', colorHex: '0xFFEF6C00'),
      ];
      await saveCategories('sleep_locations', defaultSleepLocations);
    }

  // Medication Types
  if (_prefs.getString('medication_types') == null) {
    final defaultMedicationTypes = [
      Category(id: 'melatonin', name: 'Melatonin', iconName: 'medication', colorHex: '0xFF2E7D32', defaultDosage: 50),
      Category(id: 'daridorexant', name: 'Daridorexant', iconName: 'medication', colorHex: '0xFF1565C0', defaultDosage: 50),
      Category(id: 'sertraline', name: 'Sertraline', iconName: 'medication', colorHex: '0xFF7B1FA2', defaultDosage: 50),
      Category(id: 'lisdexamfetamine', name: 'Lisdexamfetamine', iconName: 'medication', colorHex: '0xFFEF6C00', defaultDosage: 50),
    ];
    await saveCategories('medication_types', defaultMedicationTypes);
  }

  // Exercise Types
  if (_prefs.getString('exercise_types') == null) {
    final defaultExerciseTypes = [
      Category(id: 'light', name: 'Light', iconName: 'directions_walk', colorHex: '0xFF4CAF50'),
      Category(id: 'medium', name: 'Medium', iconName: 'directions_run', colorHex: '0xFFFF9800'),
      Category(id: 'heavy', name: 'Heavy', iconName: 'fitness_center', colorHex: '0xFFF44336'),
    ];
    await saveCategories('exercise_types', defaultExerciseTypes);
  }

  // Substance Types
  if (_prefs.getString('substance_types') == null) {
    final defaultSubstanceTypes = [
      Category(id: 'caffeine', name: 'Caffeine', iconName: 'coffee', colorHex: '0xFF795548'),
      Category(id: 'alcohol', name: 'Alcohol', iconName: 'wine_bar', colorHex: '0xFF9C27B0'),
    ];
    await saveCategories('substance_types', defaultSubstanceTypes);
  }
}

  Future<List<Category>> getCategories(String categoryType) async {
    final jsonString = _prefs.getString(categoryType);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Category.fromJson(json)).toList();
  }

  Future<void> saveCategories(String categoryType, List<Category> categories) async {
    final jsonString = jsonEncode(categories.map((c) => c.toJson()).toList());
    await _prefs.setString(categoryType, jsonString);
  }

  Future<Category?> getCategoryById(String categoryType, String id) async {
    final categories = await getCategories(categoryType);
    return categories.where((c) => c.id == id).firstOrNull;
  }
}

// Legacy enum compatibility
enum DayType { work, relax, travel, social, other }
enum SleepLocation { bed, couch, inTransit }

extension DayTypeExtension on DayType {
  String get displayName {
    switch (this) {
      case DayType.work: return 'Work';
      case DayType.relax: return 'Relax';
      case DayType.travel: return 'Travel';
      case DayType.social: return 'Social';
      case DayType.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case DayType.work: return Icons.work_outline;
      case DayType.relax: return Icons.self_improvement_outlined;
      case DayType.travel: return Icons.explore_outlined;
      case DayType.social: return Icons.people_outline;
      case DayType.other: return Icons.wb_sunny_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DayType.work: return Color(0xFF1565C0);
      case DayType.relax: return Color(0xFF2E7D32);
      case DayType.travel: return Color(0xFFEF6C00);
      case DayType.social: return Color(0xFF7B1FA2);
      case DayType.other: return Color(0xFF424242);
    }
  }

  static DayType fromString(String? s) {
    switch (s) {
      case 'work': return DayType.work;
      case 'relax': return DayType.relax;
      case 'travel': return DayType.travel;
      case 'social': return DayType.social;
      case 'other': return DayType.other;
      default: return DayType.other;
    }
  }
}

extension SleepLocationExtension on SleepLocation {
  String get displayName {
    switch (this) {
      case SleepLocation.bed: return 'Bed';
      case SleepLocation.couch: return 'Couch';
      case SleepLocation.inTransit: return 'In Transit';
    }
  }

  static SleepLocation fromString(String? s) {
    switch (s) {
      case 'bed': return SleepLocation.bed;
      case 'couch': return SleepLocation.couch;
      case 'inTransit': return SleepLocation.inTransit;
      default: return SleepLocation.bed;
    }
  }
}

// Caffeine or Alcohol entry model
class SubstanceEntry {
  String substanceTypeId;
  String amount;
  DateTime time;

  SubstanceEntry({this.substanceTypeId = 'caffeine', required this.amount, required this.time});

  String get name {
    switch (substanceTypeId) {
      case 'caffeine': return 'Caffeine';
      case 'alcohol': return 'Alcohol';
      // Legacy support
      case 'coffee': return 'Coffee';
      case 'tea': return 'Tea';
      case 'cola': return 'Cola';
      default: return substanceTypeId[0].toUpperCase() + substanceTypeId.substring(1);
    }
  }

  Map<String, dynamic> toJson() => {'substanceTypeId': substanceTypeId, 'amount': amount, 'time': time.toIso8601String()};
  factory SubstanceEntry.fromJson(Map<String, dynamic> json) {
    String id = json['substanceTypeId'] ?? json['name'] ?? 'caffeine';
    // Backward compatibility mappings
    if (id == 'Coffee' || id == 'Tea' || id == 'Cola') id = 'caffeine';
    if (id == 'Alcohol') id = 'alcohol';
    return SubstanceEntry(
      substanceTypeId: id, amount: json['amount'], time: DateTime.parse(json['time']));
  }
}

// Medication entry model
class MedicationEntry {
  String medicationTypeId;
  String dosage;
  DateTime time;
  MedicationEntry({required this.medicationTypeId, required this.dosage, required this.time});
  Map<String, dynamic> toJson() => {'medicationTypeId': medicationTypeId, 'dosage': dosage, 'time': time.toIso8601String()};
  factory MedicationEntry.fromJson(Map<String, dynamic> json) => MedicationEntry(
        medicationTypeId: json['medicationTypeId'] ?? json['type'], dosage: json['dosage'] ?? 'N/A', time: DateTime.parse(json['time']));
}

// Exercise entry model
class ExerciseEntry {
  String exerciseTypeId;
  DateTime startTime;
  DateTime finishTime;
  ExerciseEntry({required this.exerciseTypeId, required this.startTime, required this.finishTime});

  String get type {
    switch (exerciseTypeId) {
      case 'light': return 'Light';
      case 'medium': return 'Medium';
      case 'heavy': return 'Heavy';
      default: return exerciseTypeId;
    }
  }

  Map<String, dynamic> toJson() => {
        'exerciseTypeId': exerciseTypeId,
        'startTime': startTime.toIso8601String(),
        'finishTime': finishTime.toIso8601String()
      };
  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    if (json['startTime'] == null || json['finishTime'] == null) {
      throw FormatException("Missing time data in exercise entry");
    }
    String typeId = json['exerciseTypeId'] ?? json['type'] ?? 'light';
    // Backward compatibility: map old string values to ids
    if (typeId == 'Light') typeId = 'light';
    if (typeId == 'Medium') typeId = 'medium';
    if (typeId == 'Heavy') typeId = 'heavy';
    return ExerciseEntry(
        exerciseTypeId: typeId,
        startTime: DateTime.parse(json['startTime']),
        finishTime: DateTime.parse(json['finishTime']));
  }
}

// Sleep entry model
class SleepEntry {
  DateTime bedTime;
  DateTime wakeTime;
  DateTime fellAsleepTime;
  DateTime? outOfBedTime;

  int awakeningsCount;
  int awakeDurationMinutes;
  String? sleepLocationId;

  SleepEntry({
    required this.bedTime,
    required this.wakeTime,
    required this.fellAsleepTime,
    this.outOfBedTime,
    this.awakeningsCount = 0,
    this.awakeDurationMinutes = 0,
    this.sleepLocationId = 'bed',
  });

  Map<String, dynamic> toJson() => {
        'bedTime': bedTime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
        'fellAsleepTime': fellAsleepTime.toIso8601String(),
        'outOfBedTime': outOfBedTime?.toIso8601String(),
        'awakeningsCount': awakeningsCount,
        'awakeDurationMinutes': awakeDurationMinutes,
        'sleepLocationId': sleepLocationId,
      };

  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
        bedTime: DateTime.parse(json['bedTime']),
        wakeTime: DateTime.parse(json['wakeTime']),
        fellAsleepTime: json['fellAsleepTime'] != null
            ? DateTime.parse(json['fellAsleepTime'])
            : DateTime.parse(json['bedTime']),
        outOfBedTime: json['outOfBedTime'] != null
            ? DateTime.parse(json['outOfBedTime'])
            : null,
        awakeningsCount: json['awakeningsCount'] ?? 0,
        awakeDurationMinutes: json['awakeDurationMinutes'] ?? 0,
        sleepLocationId: json['sleepLocationId'] ?? json['sleepLocation'] ?? 'bed',
      );
  }

  // sleep statistic: get sleep duration in hours
  double get durationHours {
    return wakeTime.difference(fellAsleepTime).inMinutes / 60.0;
  }

  // sleep statistic: get sleep latency in minutes
  int get sleepLatencyMinutes => fellAsleepTime.difference(bedTime).inMinutes;

  String get sleepLocationDisplayName {
    switch (sleepLocationId) {
      case 'bed': return 'Bed';
      case 'couch': return 'Couch';
      case 'in_transit': return 'In Transit';
      default: return 'Bed';
    }
  }
}

// Daily log model for CSV export
class DailyLog {
  String? notes;
  String? dayTypeId;

  bool isSleeping;
  bool isAwakeInBed;
  DateTime? currentBedTime;
  DateTime? currentWakeTime;
  DateTime? currentFellAsleepTime;

  List<SleepEntry> sleepLog;
  List<SubstanceEntry> substanceLog;
  List<MedicationEntry> medicationLog;
  List<ExerciseEntry> exerciseLog;

  DailyLog({
    this.notes,
    this.dayTypeId,
    this.isSleeping = false,
    this.isAwakeInBed = false,
    this.currentBedTime,
    this.currentWakeTime,
    this.currentFellAsleepTime,
    List<SleepEntry>? sleepLog,
    List<SubstanceEntry>? substanceLog,
    List<MedicationEntry>? medicationLog,
    List<ExerciseEntry>? exerciseLog,
  })  : sleepLog = sleepLog ?? [],
        substanceLog = substanceLog ?? [],
        medicationLog = medicationLog ?? [],
        exerciseLog = exerciseLog ?? [];


  Map<String, dynamic> toJson() {
    return {
      'notes': notes,
      'dayTypeId': dayTypeId,
      'isSleeping': isSleeping,
      'isAwakeInBed': isAwakeInBed,
      'currentBedTime': currentBedTime?.toIso8601String(),
      'currentWakeTime': currentWakeTime?.toIso8601String(),
      'currentFellAsleepTime': currentFellAsleepTime?.toIso8601String(),
      'sleepLog': sleepLog.map((e) => e.toJson()).toList(),
      'substanceLog': substanceLog.map((e) => e.toJson()).toList(),
      'medicationLog': medicationLog.map((e) => e.toJson()).toList(),
      'exerciseLog': exerciseLog.map((e) => e.toJson()).toList(),
    };
  }

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    List<SleepEntry> loadedSleepLog = [];
    if (json['sleepLog'] != null) {
      for (var item in json['sleepLog']) {
        try { loadedSleepLog.add(SleepEntry.fromJson(item)); } catch (e) {'Error parsing sleep entry: $e';}
      }
    }
    if (loadedSleepLog.isEmpty && json['bedTime'] != null && json['wakeTime'] != null) {
       try {
         loadedSleepLog.add(SleepEntry(
           bedTime: DateTime.parse(json['bedTime']),
           wakeTime: DateTime.parse(json['wakeTime']),
           fellAsleepTime: json['fellAsleepTime'] != null ? DateTime.parse(json['fellAsleepTime']) : DateTime.parse(json['bedTime']),
         ));
       } catch (e) {'Error parsing sleep entry: $e';}
    }

    List<SubstanceEntry> loadedSubstanceLog = [];
    var rawSubstance = json['substanceLog'] ?? json['caffeineLog'];
    if (rawSubstance != null) {
      for (var item in rawSubstance) {
        try { loadedSubstanceLog.add(SubstanceEntry.fromJson(item)); } catch (e) {'Error parsing substance entry: $e';}
      }
    }

    List<MedicationEntry> loadedMedicationLog = [];
    if (json['medicationLog'] != null) {
      for (var item in json['medicationLog']) {
        try { loadedMedicationLog.add(MedicationEntry.fromJson(item)); } catch (e) {'Error parsing medication entry: $e';}
      }
    }

    List<ExerciseEntry> loadedExerciseLog = [];
    if (json['exerciseLog'] != null) {
      for (var item in json['exerciseLog']) {
        try { loadedExerciseLog.add(ExerciseEntry.fromJson(item)); } catch (e) {'Error parsing exercise entry: $e';}
      }
    }

    return DailyLog(
      notes: json['notes'],
      dayTypeId: json['dayTypeId'] ?? json['dayType'],
      isSleeping: json['isSleeping'] ?? false,
      isAwakeInBed: json['isAwakeInBed'] ?? false,
      currentBedTime: json['currentBedTime'] != null ? DateTime.parse(json['currentBedTime']) : null,
      currentWakeTime: json['currentWakeTime'] != null ? DateTime.parse(json['currentWakeTime']) : null,
      currentFellAsleepTime: json['currentFellAsleepTime'] != null ? DateTime.parse(json['currentFellAsleepTime']) : null,
      sleepLog: loadedSleepLog,
      substanceLog: loadedSubstanceLog,
      medicationLog: loadedMedicationLog,
      exerciseLog: loadedExerciseLog,
    );
  }

  // Summary statistic: total sleep hours over whole day
  double get totalSleepHours {
    double total = 0;
    for (var entry in sleepLog) {
      total += entry.durationHours;
    }
    return total;
  }
}