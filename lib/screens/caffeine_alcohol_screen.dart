import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class CaffeineAlcoholScreen extends StatefulWidget {
  final DateTime date;
  final bool autoOpenAdd; 

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

      // Handle auto-open if requested via notification
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
    // 1. Select Type
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

    // 2. Show Edit/Add Dialog
    await _showEntryDialog(type: selectedType);
  }

  Future<void> _editEntry(int index) async {
    final entry = _log.substanceLog[index];
    // Find category object for this entry to get icon/color
    final category = _substanceTypes.where((c) => c.id == entry.substanceTypeId).firstOrNull 
        ?? Category(id: entry.substanceTypeId, name: entry.name, iconName: 'local_drink', colorHex: '0xFF795548');
    
    await _showEntryDialog(existingEntry: entry, index: index, type: category);
  }

  Future<void> _showEntryDialog({SubstanceEntry? existingEntry, int? index, required Category type}) async {
    // Parse existing amount if possible, else default to 1
    int count = 1;
    if (existingEntry != null) {
      final match = RegExp(r'\d+').firstMatch(existingEntry.amount);
      if (match != null) {
        count = int.parse(match.group(0)!);
      }
    }

    DateTime selectedTime = existingEntry?.time ?? DateTime.now();
    String unit = type.id == 'alcohol' ? 'drink' : 'cup';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        int tempCount = count;
        DateTime tempTime = selectedTime;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(existingEntry == null ? 'Add ${type.name}' : 'Edit ${type.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Number of ${unit}s:'),
                      DropdownButton<int>(
                        value: tempCount,
                        items: List.generate(20, (index) => index + 1).map((val) {
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
                  // Time
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
                  child: Text(existingEntry == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final int finalCount = result['count'];
    final DateTime finalTime = result['time'];
    final String amountString = "$finalCount";

    if (existingEntry != null && index != null) {
      // Update existing
      setState(() {
        _log.substanceLog[index] = SubstanceEntry(
          substanceTypeId: type.id,
          amount: amountString,
          time: finalTime
        );
      });
    } else {
      // Create new
      final newEntry = SubstanceEntry(
        substanceTypeId: type.id, 
        amount: amountString, 
        time: finalTime
      );
      setState(() {
        _log.substanceLog.add(newEntry);
      });
    }
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
                  if (_log.substanceLog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                         child: Text(
                           "No entries yet.",
                           style: TextStyle(color: Colors.grey, fontSize: 16),
                         ),
                      ),
                    )
                  else
                    Column(
                      children: _log.substanceLog.asMap().entries.map((entry) {
                        int idx = entry.key;
                        SubstanceEntry item = entry.value;
                        final category = _substanceTypes.where((c) => c.id == item.substanceTypeId).firstOrNull;
                        final displayName = category?.name ?? item.name;
                        String unit = category?.id == 'alcohol' ? 'drink' : 'cup';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(category?.icon ?? Icons.local_drink,
                                color: category?.color ?? Colors.brown),
                            title: RichText(
                              text: TextSpan(
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black), 
                                children: [
                                  TextSpan(text: '$displayName: '), 
                                  TextSpan(text: item.amount, style: int.tryParse(item.amount) == null ? TextStyle(color: Colors.red) : null), 
                                  TextSpan(text: ' $unit'),
                                  TextSpan(text: int.tryParse(item.amount) != null ? (int.tryParse(item.amount)! > 1 ? 's' : '') : '(s)')
                                ]
                              )
                            ),
                            subtitle:
                                Text(DateFormat('h:mm a').format(item.time)),
                            onTap: () => _editEntry(idx), // Added Tap to Edit
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