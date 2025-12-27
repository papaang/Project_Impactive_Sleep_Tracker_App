import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class ExerciseScreen extends StatefulWidget {
  final DateTime date;
  final bool autoOpenAdd; 

  const ExerciseScreen({super.key, required this.date, this.autoOpenAdd = false});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;
  List<Category> _exerciseTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      final exerciseTypes = await CategoryManager().getCategories('exercise_types');
      setState(() {
        _log = log;
        _exerciseTypes = exerciseTypes;
      });

      if (widget.autoOpenAdd && mounted) {
        Future.delayed(const Duration(milliseconds: 300), _addExerciseEntry);
      }

    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  Future<TimeOfDay?> _showTimePicker(TimeOfDay initialTime,
      {required String helpText}) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
    );
  }

  Future<void> _addExerciseEntry() async {
    // 1. Select Type
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Activity Type'),
        children: _exerciseTypes.map((cat) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, cat),
          child: Row(
            children: [
              Icon(cat.icon, color: cat.color),
              const SizedBox(width: 16),
              Text(cat.name),
            ],
          ),
        )).toList(),
      ),
    );
    if (selectedType == null) return;

    await _showEntryDialog(type: selectedType);
  }

  Future<void> _editExerciseEntry(int index) async {
    final entry = _log.exerciseLog[index];
    final category = _exerciseTypes.where((c) => c.id == entry.exerciseTypeId).firstOrNull 
        ?? Category(id: entry.exerciseTypeId, name: entry.type, iconName: 'fitness_center', colorHex: '0xFFEF6C00');
    
    await _showEntryDialog(existingEntry: entry, index: index, type: category);
  }

  Future<void> _showEntryDialog({ExerciseEntry? existingEntry, int? index, required Category type}) async {
    DateTime startTime = existingEntry?.startTime ?? DateTime.now();
    DateTime endTime = existingEntry?.finishTime ?? DateTime.now().add(const Duration(minutes: 30));
    Category currentDialogType = type;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(existingEntry == null ? 'Add ${type.name}' : 'Edit Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Exercise Type Selector
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Activity Type'),
                      value: _exerciseTypes.any((c) => c.id == currentDialogType.id) ? currentDialogType.id : null,
                      items: _exerciseTypes.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(cat.icon, color: cat.color, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(cat.name, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            currentDialogType = _exerciseTypes.firstWhere((c) => c.id == val);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text("Start Time"),
                      trailing: Text(DateFormat('h:mm a').format(startTime)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(startTime));
                        if (t != null) {
                          setStateDialog(() {
                             startTime = DateTime(widget.date.year, widget.date.month, widget.date.day, t.hour, t.minute);
                             // Adjust end time if before start
                             if (endTime.isBefore(startTime)) endTime = startTime.add(const Duration(minutes: 30));
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text("End Time"),
                      trailing: Text(DateFormat('h:mm a').format(endTime)),
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(endTime));
                        if (t != null) {
                           setStateDialog(() {
                             endTime = DateTime(widget.date.year, widget.date.month, widget.date.day, t.hour, t.minute);
                           });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'start': startTime, 
                    'end': endTime,
                    'type': currentDialogType
                  }),
                  child: Text(existingEntry == null ? 'Add' : 'Save'),
                ),
              ],
            );
          }
        );
      }
    );

    if (result == null) return;

    final start = result['start'] as DateTime;
    DateTime end = result['end'] as DateTime;
    final Category selectedCategory = result['type'] as Category;
    
    // Fix logic if end is before start (assume next day? or error?)
    // If end is before start, assume it's next day (e.g. 11pm to 12am)
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    if (existingEntry != null && index != null) {
      setState(() {
        _log.exerciseLog[index] = ExerciseEntry(
          exerciseTypeId: selectedCategory.id,
          startTime: start,
          finishTime: end
        );
      });
    } else {
      setState(() {
        _log.exerciseLog.add(ExerciseEntry(
          exerciseTypeId: selectedCategory.id,
          startTime: start,
          finishTime: end
        ));
      });
    }
    _saveLog();
  }

  void _deleteExerciseEntry(int index) {
    setState(() {
      _log.exerciseLog.removeAt(index);
    });
    _saveLog();
  }

  String _getDuration(DateTime start, DateTime finish) {
    final duration = finish.difference(start);
    if (duration.isNegative) return "Invalid";
    return "${duration.inMinutes} mins";
  }

  @override
  Widget build(BuildContext context) {
    final String displayDate = DateFormat('dd/MM/yyyy').format(widget.date);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exercise Log', style: TextStyle(fontSize: 20)),
            Text(
              displayDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Exercise Entries',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _log.exerciseLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      ExerciseEntry item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.fitness_center,
                              color: Colors.orange[800]),
                          title: Text(item.type,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${DateFormat('h:mm a').format(item.startTime)} - ${DateFormat('h:mm a').format(item.finishTime)} (${_getDuration(item.startTime, item.finishTime)})'),
                          onTap: () => _editExerciseEntry(idx), // Added Tap to Edit
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteExerciseEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise Entry'),
                    onPressed: _addExerciseEntry,
                  ),
                ],
              ),
            ),
    );
  }
}