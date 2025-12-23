import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class ExerciseScreen extends StatefulWidget {
  final DateTime date;
  final bool autoOpenAdd; // Added for notification shortcut

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

      // Handle auto-open if requested
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

    final TimeOfDay? startTime = await _showTimePicker(
      TimeOfDay.now(),
      helpText: 'Select Start Time',
    );
    if (startTime == null) return;

    final TimeOfDay? finishTime = await _showTimePicker(
      startTime,
      helpText: 'Select Finish Time',
    );
    if (finishTime == null) return;

    final DateTime startDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      startTime.hour,
      startTime.minute,
    );
    final DateTime finishDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      finishTime.hour,
      finishTime.minute,
    );

    if (finishDateTime.isBefore(startDateTime)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finish time cannot be before start time.')),
        );
      }
      return;
    }

    final newEntry = ExerciseEntry(
      exerciseTypeId: selectedType.id,
      startTime: startDateTime,
      finishTime: finishDateTime,
    );

    setState(() {
      _log.exerciseLog.add(newEntry);
    });
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
           const Text('Exercise', style: TextStyle(fontSize: 20)),
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
                      'Exercise Log',
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