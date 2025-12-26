import 'dart:math';
import 'dart:ui' as ui; // Added import for ui.TextDirection and ui.PictureRecorder
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../log_service.dart';
import '../models.dart';
import 'medication_screen.dart';
import 'caffeine_alcohol_screen.dart';
import 'exercise_screen.dart';
import 'notes_screen.dart';

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
    return DateFormat('HH:mm').format(dt);
  }

  Future<DateTime?> _selectDateTime(DateTime? initialDate, {String? helpText}) async {
    DateTime now = DateTime.now();
    initialDate = initialDate ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      helpText: helpText,
    );
    if (date == null) return null;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: helpText
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
          children: _dayTypes.map((type) {
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
          }).toList(),
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

  Future<void> _resetDayType() async {
    setState(() {
      _log.dayTypeId = null;
    });
    await _logService.saveDailyLog(widget.date, _log);

    // Show notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Day type reset'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editSleepEntry(int index, SleepEntry entry) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside during editing
      builder: (context) {
        return SleepSessionEditor(
          initialEntry: entry,
          onSave: (updatedEntry) {
            setState(() {
              _log.sleepLog[index] = updatedEntry;
            });
            _logService.saveDailyLog(widget.date, _log);
          },
        );
      },
    );
  }

  Future<void> _addSleepEntry() async {
    final now = DateTime.now();
    final defaultBed = DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 0).subtract(Duration(days: 1));
    final defaultAsleep = defaultBed.add(Duration(minutes: 30));
    final defaultWake = defaultBed.add(Duration(hours: 8, minutes: 30));
    final defaultOut = defaultWake.add(Duration(minutes: 30));

    final newEntry = SleepEntry(
      bedTime: defaultBed, 
      fellAsleepTime: defaultAsleep, 
      wakeTime: defaultWake, 
      outOfBedTime: defaultOut
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return SleepSessionEditor(
          initialEntry: newEntry,
          isNew: true,
          onSave: (updatedEntry) {
            setState(() {
              _log.sleepLog.add(updatedEntry);
            });
            _logService.saveDailyLog(widget.date, _log);
          },
        );
      },
    );
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
                  backgroundColor: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.color.withOpacity(0.1),
                  borderColor: _dayTypes.where((c) => c.id == _log.dayTypeId).firstOrNull?.color,
                  onPressed: _showDayTypeDialog,
                  onLongPress: _resetDayType,
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
                  label: 'Caffeine & Alcohol',
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

class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.subtitle,
    this.backgroundColor,
    this.borderColor,
    this.onLongPress,
  });
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool useCustomStyle = backgroundColor != null && borderColor != null;

    if (useCustomStyle) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor!, width: 1.5),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
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
    } else {
      return Card(
        elevation: 1.0,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
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

// ---------------------------------------------------------------------------
// --- NEW INTERACTIVE VISUAL SLEEP EDITOR ---
// ---------------------------------------------------------------------------

class SleepSessionEditor extends StatefulWidget {
  final SleepEntry initialEntry;
  final Function(SleepEntry) onSave;
  final bool isNew;

  const SleepSessionEditor({
    super.key, 
    required this.initialEntry, 
    required this.onSave,
    this.isNew = false,
  });

  @override
  State<SleepSessionEditor> createState() => _SleepSessionEditorState();
}

enum _SleepHandle { none, bed, asleep, wake, out }

class _SleepSessionEditorState extends State<SleepSessionEditor> {
  // Step 1: Times, Step 2: Details
  int _currentStep = 1;

  late DateTime _bedTime;
  late DateTime _asleepTime;
  late DateTime _wakeTime;
  late DateTime _outTime;
  late int _awakenings;
  late int _awakeMins;
  late String _locationId;
  List<Category> _sleepLocations = [];

  _SleepHandle _draggingHandle = _SleepHandle.none;

  final TextEditingController _awakeningsCtrl = TextEditingController();
  final TextEditingController _awakeMinsCtrl = TextEditingController();

  static const double _clockSize = 300.0;
  static const double _outerPadding = 35.0; // Radius for Bed/Out
  static const double _innerPadding = 65.0; // Radius for Asleep/Wake

  @override
  void initState() {
    super.initState();
    _bedTime = widget.initialEntry.bedTime;
    _asleepTime = widget.initialEntry.fellAsleepTime;
    _wakeTime = widget.initialEntry.wakeTime;
    _outTime = widget.initialEntry.outOfBedTime ?? widget.initialEntry.wakeTime;
    _awakenings = widget.initialEntry.awakeningsCount;
    _awakeMins = widget.initialEntry.awakeDurationMinutes;
    _locationId = widget.initialEntry.sleepLocationId ?? 'bed';

    _awakeningsCtrl.text = _awakenings.toString();
    _awakeMinsCtrl.text = _awakeMins.toString();
    
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locs = await CategoryManager().getCategories('sleep_locations');
    if (mounted) {
      setState(() {
        _sleepLocations = locs;
        if (_sleepLocations.isNotEmpty && !_sleepLocations.any((c) => c.id == _locationId)) {
           _locationId = _sleepLocations.first.id;
        }
      });
    }
  }

  Future<void> _pickTime(String type) async {
    DateTime initial;
    switch(type) {
      case 'bed': initial = _bedTime; break;
      case 'asleep': initial = _asleepTime; break;
      case 'wake': initial = _wakeTime; break;
      case 'out': initial = _outTime; break;
      default: initial = DateTime.now();
    }

    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "Select $type date",
    );
    
    if (d == null) return; 

    final TimeOfDay? t = await showTimePicker(
      context: context, 
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: "Select $type time"
    );

    if (t != null) {
      setState(() {
        final newDt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        switch(type) {
          case 'bed': _bedTime = newDt; break;
          case 'asleep': _asleepTime = newDt; break;
          case 'wake': _wakeTime = newDt; break;
          case 'out': _outTime = newDt; break;
        }
      });
    }
  }

  // --- INTERACTION LOGIC (IMPROVED) ---

  void _updateTimeFromTouch(Offset localPosition) {
    final Offset center = Offset(_clockSize / 2, _clockSize / 2);
    final Offset delta = localPosition - center;
    
    double angle = atan2(delta.dy, delta.dx);
    
    double normalizedAngle = angle + (pi / 2);
    if (normalizedAngle < 0) normalizedAngle += 2 * pi;
    
    double totalHours = (normalizedAngle / (2 * pi)) * 24.0;
    
    int hour = totalHours.floor();
    int minute = ((totalHours - hour) * 60).round();
    
    int snap = 5;
    minute = (minute / snap).round() * snap;
    if (minute == 60) {
      minute = 0;
      hour += 1;
    }
    if (hour == 24) hour = 0;

    setState(() {
      DateTime updateDate(DateTime original) {
        return DateTime(original.year, original.month, original.day, hour, minute);
      }

      switch (_draggingHandle) {
        case _SleepHandle.bed:
          _bedTime = updateDate(_bedTime);
          break;
        case _SleepHandle.asleep:
          _asleepTime = updateDate(_asleepTime);
          break;
        case _SleepHandle.wake:
          _wakeTime = updateDate(_wakeTime);
          break;
        case _SleepHandle.out:
          _outTime = updateDate(_outTime);
          break;
        case _SleepHandle.none:
          break;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final Offset local = details.localPosition;
    final Offset center = Offset(_clockSize / 2, _clockSize / 2);
    
    final double touchRadius = (local - center).distance;
    final double outerRingR = (_clockSize / 2) - _outerPadding;
    final double innerRingR = (_clockSize / 2) - _innerPadding;
    final double midRadius = (outerRingR + innerRingR) / 2;

    double getAngularDist(DateTime dt) {
        final double dx = local.dx - center.dx;
        final double dy = local.dy - center.dy;
        double touchAngle = atan2(dy, dx);
        
        double totalHours = dt.hour + dt.minute / 60.0;
        double dtAngle = (totalHours / 24.0) * 2 * pi - (pi / 2);
        
        touchAngle = (touchAngle + 2 * pi) % (2 * pi);
        dtAngle = (dtAngle + 2 * pi) % (2 * pi);
        
        double diff = (touchAngle - dtAngle).abs();
        if (diff > pi) diff = 2 * pi - diff;
        return diff;
    }

    _draggingHandle = _SleepHandle.none;

    if (touchRadius > midRadius) {
       double distBed = getAngularDist(_bedTime);
       double distOut = getAngularDist(_outTime);
       if (distBed <= distOut) {
         _draggingHandle = _SleepHandle.bed;
       } else {
         _draggingHandle = _SleepHandle.out;
       }
    } else {
       double distAsleep = getAngularDist(_asleepTime);
       double distWake = getAngularDist(_wakeTime);
       if (distAsleep <= distWake) {
         _draggingHandle = _SleepHandle.asleep;
       } else {
         _draggingHandle = _SleepHandle.wake;
       }
    }

    // Larger interaction radius for easier grabbing
    Offset getHandlePos(DateTime dt, double rPadding) {
      double r = (_clockSize / 2) - rPadding;
      double totalHours = dt.hour + dt.minute / 60.0;
      double angle = (totalHours / 24.0) * 2 * pi - (pi / 2);
      return Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
    }
    
    // Check linear distance to confirm intent (prevent accidental drags from center)
    double targetR = (_draggingHandle == _SleepHandle.bed || _draggingHandle == _SleepHandle.out) 
        ? outerRingR : innerRingR;
    DateTime targetTime;
    switch(_draggingHandle) {
        case _SleepHandle.bed: targetTime = _bedTime; break;
        case _SleepHandle.out: targetTime = _outTime; break;
        case _SleepHandle.asleep: targetTime = _asleepTime; break;
        case _SleepHandle.wake: targetTime = _wakeTime; break;
        default: targetTime = DateTime.now();
    }
    
    double distToHandle = (local - getHandlePos(targetTime, 
        (_draggingHandle == _SleepHandle.bed || _draggingHandle == _SleepHandle.out) ? _outerPadding : _innerPadding)
    ).distance;

    if (distToHandle < 40.0) { // 40px hit area
      _updateTimeFromTouch(local);
    } else {
      _draggingHandle = _SleepHandle.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingHandle == _SleepHandle.none) return;
    _updateTimeFromTouch(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _draggingHandle = _SleepHandle.none;
    setState(() {}); // Redraw to remove highlight
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24.0),
        child: _currentStep == 1 
            ? _buildTimeStep(isDark) 
            : _buildDetailsStep(isDark),
      ),
    );
  }

  // --- STEP 1: TIMES (No Scrolling needed for main clock interaction) ---
  Widget _buildTimeStep(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.isNew ? "Set Times (1/2)" : "Edit Times (1/2)",
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white70 : Colors.blueGrey[800]
          ),
        ),
        const SizedBox(height: 24),
        
        Center(
          child: SizedBox(
            width: _clockSize,
            height: _clockSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, 
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                painter: SleepEditorPainter(
                  _bedTime, _asleepTime, _wakeTime, _outTime, 
                  _outerPadding, _innerPadding,
                  isDark: isDark,
                  activeHandle: _draggingHandle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _TimeTile(label: "Bed Time", time: _bedTime, color: Colors.indigo, icon: Icons.bed, onTap: () => _pickTime('bed')),
            _TimeTile(label: "Asleep", time: _asleepTime, color: Colors.cyan, icon: Icons.nights_stay, onTap: () => _pickTime('asleep')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _TimeTile(label: "Wake Up", time: _wakeTime, color: Colors.cyan, icon: Icons.wb_sunny, onTap: () => _pickTime('wake')),
            _TimeTile(label: "Out of Bed", time: _outTime, color: Colors.indigo, icon: Icons.directions_walk, onTap: () => _pickTime('out')),
          ],
        ),

        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context), 
              label: Text("Cancel", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {
                // Basic validation before next
                if (_asleepTime.isBefore(_bedTime)) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Asleep time cannot be before Bed time")));
                   return;
                }
                setState(() => _currentStep = 2);
              }, 
              label: Text("Next")
            ),
          ],
        )
      ],
    );
  }

  // --- STEP 2: DETAILS ---
  Widget _buildDetailsStep(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Session Details (2/2)",
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white70 : Colors.blueGrey[800]
          ),
        ),
        const SizedBox(height: 32),

        if (_sleepLocations.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _locationId,
            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            decoration: const InputDecoration(
              labelText: "Sleep Location",
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: _sleepLocations.map((cat) {
              return DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _locationId = val);
            },
          ),
        
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _awakeningsCtrl,
                decoration: InputDecoration(
                  labelText: "Awakenings", 
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.restart_alt),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _awakeMinsCtrl,
                decoration: InputDecoration(
                  labelText: "Awake Mins", 
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixText: "min",
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: Icon(Icons.arrow_back, size: 18),
              onPressed: () => setState(() => _currentStep = 1), 
              label: Text("Back", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              onPressed: () {
                final updatedEntry = SleepEntry(
                  bedTime: _bedTime,
                  fellAsleepTime: _asleepTime,
                  wakeTime: _wakeTime,
                  outOfBedTime: _outTime,
                  awakeningsCount: int.tryParse(_awakeningsCtrl.text) ?? 0,
                  awakeDurationMinutes: int.tryParse(_awakeMinsCtrl.text) ?? 0,
                  sleepLocationId: _locationId
                );
                widget.onSave(updatedEntry);
                Navigator.pop(context);
              }, 
              label: Text("Save Session")
            ),
          ],
        )
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final DateTime time;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeTile({required this.label, required this.time, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.25 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.5 : 0.3))
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]), 
                SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(DateFormat('HH:mm').format(time), style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
            Text(DateFormat('MMM dd').format(time), style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])), 
          ],
        ),
      ),
    );
  }
}

class SleepEditorPainter extends CustomPainter {
  final DateTime bedTime;
  final DateTime asleepTime;
  final DateTime wakeTime;
  final DateTime outTime;
  final double outerPadding;
  final double innerPadding;
  final bool isDark;
  final _SleepHandle activeHandle; // New parameter

  SleepEditorPainter(
    this.bedTime, this.asleepTime, this.wakeTime, this.outTime,
    this.outerPadding, this.innerPadding, {this.isDark = false, this.activeHandle = _SleepHandle.none}
  );

  double getAngle(DateTime dt) {
    // 0 is Top (-pi/2)
    // 24h clock
    double totalHours = dt.hour + dt.minute / 60.0;
    return (totalHours / 24.0) * 2 * pi - (pi / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Background Circle
    final bgPaint = Paint()..color = isDark ? const Color(0xFF121212) : Colors.grey[200]!;
    canvas.drawCircle(center, radius, bgPaint);

    // Ticks & Numbers
    final tickPaint = Paint()..color = isDark ? Colors.grey[700]! : Colors.grey[400]!..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (int i = 0; i < 24; i += 2) {
      double angle = (i / 24.0) * 2 * pi - (pi / 2);
      
      // Tick
      canvas.drawLine(
        Offset(center.dx + (radius - 5) * cos(angle), center.dy + (radius - 5) * sin(angle)),
        Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        tickPaint
      );

      // Number
      if (i % 6 == 0) {
        textPainter.text = TextSpan(text: i.toString(), style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[600]));
        textPainter.layout();
        canvas.drawText(
          textPainter, 
          Offset(center.dx + (radius - 20) * cos(angle) - textPainter.width/2, center.dy + (radius - 20) * sin(angle) - textPainter.height/2)
        );
      }
    }

    // --- ARCS ---
    final bedStartAngle = getAngle(bedTime);
    final outAngle = getAngle(outTime);
    
    // Calculate sweep. Handle day wrap.
    double bedSweep = outAngle - bedStartAngle;
    if (bedSweep <= 0) bedSweep += 2 * pi;

    final bedPaint = Paint()
      ..color = Colors.indigo.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    
    // Draw Bed Arc (Outer)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - outerPadding), 
      bedStartAngle, 
      bedSweep, 
      false, 
      bedPaint
    );

    final asleepStartAngle = getAngle(asleepTime);
    final wakeAngle = getAngle(wakeTime);
    
    double sleepSweep = wakeAngle - asleepStartAngle;
    if (sleepSweep <= 0) sleepSweep += 2 * pi;

    final sleepPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    // Draw Sleep Arc (Inner)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - innerPadding), 
      asleepStartAngle, 
      sleepSweep, 
      false, 
      sleepPaint
    );

    // --- HANDLES / ICONS ---
    // Helper to draw handle with active state
    void drawHandle(double angle, double r, Color c, IconData icon, _SleepHandle handleType) {
      final pos = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      
      final bool isActive = activeHandle == handleType;
      final double size = isActive ? 22.0 : 14.0; // Larger when active, easier to see

      // Shadow
      canvas.drawCircle(
        pos, 
        size, 
        Paint()
          ..color = Colors.black26
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4)
      );
      
      // Handle - Dark Charcoal in Dark Mode
      canvas.drawCircle(pos, size, Paint()..color = isDark ? const Color(0xFF2C2C2C) : Colors.white);
      // Dot
      canvas.drawCircle(pos, 4, Paint()..color = c);
    }

    drawHandle(bedStartAngle, radius - outerPadding, Colors.indigo, Icons.bed, _SleepHandle.bed);
    drawHandle(outAngle, radius - outerPadding, Colors.indigo, Icons.directions_walk, _SleepHandle.out);
    
    drawHandle(asleepStartAngle, radius - innerPadding, Colors.cyan, Icons.nights_stay, _SleepHandle.asleep);
    drawHandle(wakeAngle, radius - innerPadding, Colors.cyan, Icons.wb_sunny, _SleepHandle.wake);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Extension to help canvas.drawText (Flutter standard canvas doesn't have drawText directly, uses TextPainter.paint)
extension CanvasText on Canvas {
  void drawText(TextPainter tp, Offset offset) {
    tp.paint(this, offset);
  }
}