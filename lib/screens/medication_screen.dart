import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';

class MedicationScreen extends StatefulWidget {
  final DateTime date;
  const MedicationScreen({super.key, required this.date});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final LogService _logService = LogService();
  late DailyLog _log;
  bool _isLoading = true;
  List<Category> _medicationTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    try {
      setState(() => _isLoading = true);
      final log = await _logService.getDailyLog(widget.date);
      final medicationTypes = await CategoryManager().getCategories('medication_types');
      setState(() {
        _log = log;
        _medicationTypes = medicationTypes;
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

  Future<void> _addMedicationEntry() async {
    final Category? selectedType = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Medication'),
        children: [
          ..._medicationTypes.map((cat) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, cat),
            child: Row(
              children: [
                Icon(cat.icon, color: cat.color),
                const SizedBox(width: 16),
                Text(cat.name),
              ],
            ),
          )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, Category(id: 'custom', name: 'Other...', iconName: 'medication', colorHex: '0xFF424242')),
            child: Text('Other...'),
          ),
        ],
      ),
    );

    String? typeId;
    if (selectedType != null) {
      if (selectedType.id == 'custom') {
        final controller = TextEditingController();
        final customName = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Enter Medication Name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: 'e.g. Ibuprofen'),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text('Save'),
                onPressed: () => Navigator.pop(context, controller.text),
              ),
            ],
          ),
        );
        if (customName == null || customName.isEmpty) return;
        typeId = customName;
      } else {
        typeId = selectedType.id;
      }
    } else {
      return;
    }

    String? dosage = await showDialog<String>(
        context: context,
        builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
                title: const Text('Enter Dosage (mg)'),
                content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'e.g. 5 or 10'),
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
                ],
            );
        }
    );

    if (dosage == null || dosage.isEmpty) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select Medication Time',
    );
    if (time == null) return;

    final DateTime entryTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );
    final newEntry = MedicationEntry(medicationTypeId: typeId, dosage: dosage, time: entryTime);
    setState(() {
      _log.medicationLog.add(newEntry);
    });
    _saveLog();
  }

  void _deleteMedicationEntry(int index) {
    setState(() {
      _log.medicationLog.removeAt(index);
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
            const Text('Medication Log', style: TextStyle(fontSize: 20)),
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
                      'Medication Log',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children:
                        _log.medicationLog.asMap().entries.map((entry) {
                      int idx = entry.key;
                      MedicationEntry item = entry.value;
                      final category = _medicationTypes.where((c) => c.id == item.medicationTypeId).firstOrNull;
                      final displayName = category?.name ?? item.medicationTypeId;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(category?.icon ?? Icons.medication_outlined,
                              color: category?.color ?? Colors.green[800]),
                          title: Text("$displayName (${item.dosage}mg)",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text(DateFormat('h:mm a').format(item.time)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteMedicationEntry(idx),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication Entry'),
                    onPressed: _addMedicationEntry,
                  ),
                ],
              ),
            ),
    );
  }
}
