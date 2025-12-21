import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class CaffeineAlcoholScreen extends StatefulWidget {
  final DateTime date;
  const CaffeineAlcoholScreen({super.key, required this.date});

  @override
  State<CaffeineAlcoholScreen> createState() => _CaffeineAlcoholScreenState();
}

class _CaffeineAlcoholScreenState extends State<CaffeineAlcoholScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;
  List<Category> _substanceTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      final substanceTypes = await CategoryManager().getCategories('substance_types');
      setState(() {
        _log = log;
        _substanceTypes = substanceTypes;
      });
    } catch (e) {
       // handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLog() async {
    await _logService.saveDailyLog(widget.date, _log);
  }

  Future<void> _addEntry() async {
    int cups = 1; // Default to 1 cup
    DateTime selectedTime = DateTime.now(); // Default to current time

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        int tempCups = cups;
        DateTime tempTime = selectedTime;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Caffeine'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Cups: '),
                    DropdownButton<int>(
                      value: tempCups,
                      items: List.generate(10, (i) => i + 1).map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => tempCups = newValue);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Time: ${DateFormat('h:mm a').format(tempTime)}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(tempTime),
                    );
                    if (picked != null) {
                      setState(() {
                        tempTime = DateTime(
                          widget.date.year,
                          widget.date.month,
                          widget.date.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null), // Cancel
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, {'cups': tempCups, 'time': tempTime}), // Confirm
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return; // Cancelled

    final int finalCups = result['cups'];
    final DateTime finalTime = result['time'];

    final newEntry = SubstanceEntry(
      substanceTypeId: 'coffee',
      amount: finalCups.toString(),
      time: finalTime,
    );
    setState(() {
      _log.substanceLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteEntry(int index) {
    setState(() {
      _log.substanceLog.removeAt(index);
    });
    _saveLog();
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
            const Text('Caffeine', style: TextStyle(fontSize: 20)),
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
                      'Caffeine Log',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _log.substanceLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      SubstanceEntry item = entry.value;
                      final category = _substanceTypes.where((c) => c.id == item.substanceTypeId).firstOrNull;
                      final displayName = category?.name ?? item.name;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(category?.icon ?? Icons.local_drink,
                              color: category?.color ?? Colors.brown),
                          // Display if amount>1, display 'x cups', elif amount<1 display 'cup', elif int parsing error display 'cup'
                          title: Text("$displayName: ${item.amount} cup${(int.tryParse(item.amount)!= null ? int.tryParse(item.amount)! : 0) > 1 ? 's' : ''}",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Caffeine Entry'),
                    onPressed: _addEntry,
                  ),
                ],
              ),
            ),
    );
  }
}
