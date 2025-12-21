import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../log_service.dart';
import '../models.dart';
import 'medication_screen.dart';
import 'caffeine_alcohol_screen.dart';
import 'exercise_screen.dart';
import 'notes_screen.dart';
import 'category_management_screen.dart';

class EventScreen extends StatefulWidget {
  final DateTime date;
  const EventScreen({super.key, required this.date});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;
  List<Category> _dayTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      final dayTypes = await CategoryManager().getCategories('day_types');
      setState(() {
        _log = log;
        _dayTypes = dayTypes;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return DateFormat('h:mm a').format(dt);
  }

  Future<DateTime?> _selectDateTime(DateTime? initialDate, {String? helpText}) async {
    DateTime now = DateTime.now();
    initialDate = initialDate ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: helpText // Pass custom help text
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showDayTypeDialog() async {
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Day Type'),
          children: [
            ..._dayTypes.map((type) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, type),
                child: Row(
                  children: [
                    Icon(type.icon, color: type.color),
                    const SizedBox(width: 16),
                    Text(type.name),
                  ],
                ),
              );
            }),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                );
                // Reload day types after returning from category management
                final dayTypes = await CategoryManager().getCategories('day_types');
                setState(() {
                  _dayTypes = dayTypes;
                });
              },
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.grey),
                  const SizedBox(width: 16),
                  Text('Manage Categories'),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (selectedType != null) {
      setState(() {
        _log.dayTypeId = selectedType.id;
      });
      await _logService.saveDailyLog(widget.date, _log);
    }
  }

  Future<void> _editSleepEntry(int index, SleepEntry entry) async {
    DateTime? bedTime = entry.bedTime;
    DateTime? fellAsleepTime = entry.fellAsleepTime;
    DateTime? wakeTime = entry.wakeTime;
    DateTime? outTime = entry.outOfBedTime;
    int awakenings = entry.awakeningsCount;
    int awakeMins = entry.awakeDurationMinutes;
    String sleepLocationId = entry.sleepLocationId ?? 'bed';

    await showDialog(
      context: context,
      builder: (context) {
        final countCtrl = TextEditingController(text: awakenings.toString());
        final durCtrl = TextEditingController(text: awakeMins.toString());

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Sleep Session'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(title: Text('Bed: ${_formatTime(bedTime)}'), onTap: () async {
                       var t = await _selectDateTime(bedTime, helpText: "Select Bed Time"); if(t!=null) setDialogState(()=> bedTime = t);
                    }),
                    ListTile(title: Text('Asleep: ${_formatTime(fellAsleepTime)}'), onTap: () async {
                       var t = await _selectDateTime(fellAsleepTime, helpText: "Select Asleep Time"); if(t!=null) setDialogState(()=> fellAsleepTime = t);
                    }),
                    ListTile(title: Text('Wake: ${_formatTime(wakeTime)}'), onTap: () async {
                       var t = await _selectDateTime(wakeTime, helpText: "Select Wake Time"); if(t!=null) setDialogState(()=> wakeTime = t);
                    }),
                    ListTile(title: Text('Out: ${_formatTime(outTime)}'), onTap: () async {
                       var t = await _selectDateTime(outTime, helpText: "Select Out of Bed Time"); if(t!=null) setDialogState(()=> outTime = t);
                    }),
                    TextField(
                      controller: countCtrl,
                      decoration: InputDecoration(labelText: 'Number of Awakenings'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: durCtrl,
                      decoration: InputDecoration(labelText: 'Total Awake Time (mins)'),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(title: Text('Location: $sleepLocationId'), onTap: () async {
                      final categories = await CategoryManager().getCategories('sleep_locations');
                      final Category? selected = await showDialog<Category>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text('Select Sleep Location'),
                          children: [
                            ...categories.map((cat) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, cat),
                              child: Text(cat.name),
                            )),
                            SimpleDialogOption(
                              onPressed: () async {
                                Navigator.pop(context); // Close the dialog
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                                );
                                // Reload sleep locations after returning from category management
                                setDialogState(() {
                                  // Note: Since categories are reloaded, but the dialog is closed, the next time it's opened it will have updated categories
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.settings, color: Colors.grey),
                                  const SizedBox(width: 16),
                                  Text('Manage Categories'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                      if (selected != null) setDialogState(() => sleepLocationId = selected.id);
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(context), child: Text('Cancel')),
                TextButton(onPressed: () {
                    awakenings = int.tryParse(countCtrl.text) ?? 0;
                    awakeMins = int.tryParse(durCtrl.text) ?? 0;

                    // Checking for incorrect order of sleep entry times
                    if (fellAsleepTime!.isBefore(bedTime!)) {
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Asleep time cannot be before bed time.')));
                      }
                      return;
                    }
                    if (wakeTime!.isBefore(fellAsleepTime!)) {
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wake time cannot be before sleep time.')));
                      }
                      return;
                    }
                    if (outTime!.isBefore(wakeTime!)) {
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Out of bed time cannot be before wake time.')));
                      }
                      return;
                    }

                   setState(() {
                     _log.sleepLog[index] = SleepEntry(
                       bedTime: bedTime!,
                       wakeTime: wakeTime!,
                       fellAsleepTime: fellAsleepTime!,
                       outOfBedTime: outTime!,
                       awakeningsCount: awakenings,
                       awakeDurationMinutes: awakeMins,
                       sleepLocationId: sleepLocationId,
                     );
                   });
                   _logService.saveDailyLog(widget.date, _log);
                   Navigator.pop(context);
                }, child: Text('Save')),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _addSleepEntry() async {
    DateTime now = DateTime.now();
    String sleepLocationId = 'bed';

    DateTime? bedTime = await _selectDateTime(now, helpText: "Select Bed Time");
    if (bedTime == null) return;

    DateTime? fellAsleepTime = await _selectDateTime(bedTime, helpText: "Select Asleep Time");
    if (fellAsleepTime == null) return;

    DateTime? wakeTime = await _selectDateTime(fellAsleepTime.add(Duration(hours: 8)), helpText: "Select Wake Time");
    if (wakeTime == null) return;

    DateTime? outTime = await _selectDateTime(wakeTime, helpText: "Select Out of Bed Time");
    if (outTime == null) return;

    final categories = await CategoryManager().getCategories('sleep_locations');
    final Category? selected = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Sleep Location'),
        children: [
          ...categories.map((cat) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, cat),
            child: Text(cat.name),
          )),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
              );
              // Reload sleep locations after returning from category management
              // Note: Since categories are reloaded, but the dialog is closed, the next time it's opened it will have updated categories
            },
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.grey),
                const SizedBox(width: 16),
                Text('Manage Categories'),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null) sleepLocationId = selected.id;

    // Checking for incorrect order of sleep entry times
    if (fellAsleepTime.isBefore(bedTime)) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Asleep time cannot be before bed time.')));
       }
       return;
    }
    if (wakeTime.isBefore(fellAsleepTime)) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wake time cannot be before sleep time.')));
       }
       return;
    }
    if (outTime.isBefore(wakeTime)) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Out of bed time cannot be before wake time.')));
       }
       return;
    }

    setState(() {
      _log.sleepLog.add(SleepEntry(
        bedTime: bedTime,
        wakeTime: wakeTime,
        fellAsleepTime: fellAsleepTime,
        outOfBedTime: outTime,
        sleepLocationId: sleepLocationId,
      ));
    });
    await _logService.saveDailyLog(widget.date, _log);
  }

  void _deleteSleepEntry(int index) {
    setState(() {
      _log.sleepLog.removeAt(index);
    });
    _logService.saveDailyLog(widget.date, _log);
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
            const Text('Event', style: TextStyle(fontSize: 20)),
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
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('Sleep Sessions',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)
                  ),
                ),
                const SizedBox(height: 8),

                if (_log.sleepLog.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(8.0),
                     child: Text('No sleep recorded for this day.', style: TextStyle(color: Colors.grey)),
                   ),

                ..._log.sleepLog.asMap().entries.map((entry) {
                    int idx = entry.key;
                    SleepEntry sleep = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.king_bed_outlined, color: Colors.indigo[800]),
                        title: Text("${_formatTime(sleep.bedTime)} - ${_formatTime(sleep.wakeTime)}"),
                        subtitle: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("Asleep: ${_formatTime(sleep.fellAsleepTime)}"),
                             Text("Out: ${_formatTime(sleep.outOfBedTime ?? sleep.wakeTime)}"),
                             if (sleep.awakeningsCount > 0)
                               Text("Awake: ${sleep.awakeDurationMinutes}m (${sleep.awakeningsCount}x)")
                           ]
                        ),
                        onTap: () => _editSleepEntry(idx, sleep),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteSleepEntry(idx),
                        ),
                      ),
                    );
                }),

                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Add Sleep Session'),
                  onPressed: _addSleepEntry,
                ),
                const SizedBox(height: 24),
                Divider(),
                const SizedBox(height: 24),

                _EventButton(
                  label: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.displayName ?? 'Type of Day',
                  icon: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.icon ?? Icons.wb_sunny_outlined,
                  color: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.color ?? Colors.indigo[800]!,
                  backgroundColor: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.color.withAlpha(26),
                  onPressed: _showDayTypeDialog,
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Medication',
                  subtitle: _log.medicationLog.isNotEmpty ? "${_log.medicationLog.length} entries" : null,
                  icon: Icons.medication_outlined,
                  color: Colors.green[800]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicationScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Caffeine',
                  subtitle: _log.substanceLog.isNotEmpty ? "${_log.substanceLog.length} entries" : null,
                  icon: Icons.coffee_outlined,
                  color: Colors.brown[600]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaffeineAlcoholScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Exercise',
                  subtitle: _log.exerciseLog.isNotEmpty ? "${_log.exerciseLog.length} entries" : null,
                  icon: Icons.fitness_center_outlined,
                  color: Colors.orange[800]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
                const SizedBox(height: 16),
                _EventButton(
                  label: 'Notes',
                  subtitle: _log.notes != null && _log.notes!.isNotEmpty ? "Added" : null,
                  icon: Icons.note_alt_outlined,
                  color: Colors.grey[700]!,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotesScreen(date: widget.date),
                      ),
                    ).then((_) => _loadLog());
                  },
                ),
              ],
            ),
    );
  }
}

// class _SleepTimeChip currently unused
class _SleepTimeChip extends StatelessWidget {
  const _SleepTimeChip({required this.label, required this.time});
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.subtitle,
    this.backgroundColor,
  });
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor != null) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: color,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      );
    } else {
      return Card(
        elevation: 1.0,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      );
    }
  }
}
