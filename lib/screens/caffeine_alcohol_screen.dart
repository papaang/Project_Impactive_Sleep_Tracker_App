import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class CaffeineAlcoholScreen extends StatefulWidget {
  final DateTime date;
   final bool autoOpenAdd; // Added for notification shortcut

  const CaffeineAlcoholScreen({super.key, required this.date, this.autoOpenAdd = false});
  

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
      if (widget.autoOpenAdd && mounted) {
        Future.delayed(const Duration(milliseconds: 300), _addEntry);
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

  Future<void> _addEntry() async {
    // 1. Select Type (Caffeine or Alcohol)
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Substance'),
        children: _substanceTypes.map((cat) => SimpleDialogOption(
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

    // 2. Custom Popup for Amount & Time
    int count = 1; // Default
    DateTime selectedTime = DateTime.now(); // Default current time
    String unit = selectedType.id == 'alcohol' ? 'drink' : 'cup';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to update state within the dialog
        int tempCount = count;
        DateTime tempTime = selectedTime;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Add ${selectedType.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Number of ${unit}s:'),
                      DropdownButton<int>(
                        value: tempCount,
                        items: List.generate(10, (index) => index + 1).map((val) {
                          return DropdownMenuItem(
                            value: val,
                            child: Text(val.toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => tempCount = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Time Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Time:"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat('h:mm a').format(tempTime),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(tempTime),
                      );
                      if (picked != null) {
                        setStateDialog(() {
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
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {'count': tempCount, 'time': tempTime});
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return; // Cancelled

    final int finalCount = result['count'];
    final DateTime finalTime = result['time'];
    final String amountString = "$finalCount $unit${finalCount > 1 ? 's' : ''}";

    final newEntry = SubstanceEntry(
      substanceTypeId: selectedType.id, 
      amount: amountString, 
      time: finalTime
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
            const Text('Caffeine & Alcohol', style: TextStyle(fontSize: 20)),
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
                      'Consumption Log',
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
                          title: Text("$displayName: ${item.amount}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Consumption Entry'),
                    onPressed: _addEntry,
                  ),
                ],
              ),
            ),
    );
  }
}