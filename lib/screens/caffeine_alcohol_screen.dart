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
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Substance'),
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

    List<String> amountOptions;
    if (selectedType.id == 'alcohol') {
      amountOptions = ['1 drink', '2 drinks', '3 drinks', '4 drinks', '5+ drinks'];
    } else {
      amountOptions = ['One cup', 'Two cups', 'Three cups', 'Four cups'];
    }

    final String? amount = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Amount (${selectedType.name})'),
        children: amountOptions.map((opt) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, opt),
          child: Text(opt),
        )).toList(),
      ),
    );
    if (amount == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Time of Consumption',
    );
    if (time == null) return;

    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );

    final newEntry = SubstanceEntry(substanceTypeId: selectedType.id, amount: amount, time: entryTime);
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
                    label: const Text('Add Consumption Entry'),
                    onPressed: _addEntry,
                  ),
                ],
              ),
            ),
    );
  }
}
