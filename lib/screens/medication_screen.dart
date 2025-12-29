import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../log_service.dart';
import 'category_management_screen.dart'; // Added import

class MedicationScreen extends StatefulWidget {
  final DateTime date;
  final bool autoOpenAdd; 

  const MedicationScreen({super.key, required this.date, this.autoOpenAdd = false});

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
      
      // Auto-open logic
      if (widget.autoOpenAdd && mounted) {
        Future.delayed(const Duration(milliseconds: 300), _showAddMedicationSheet);
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

  Future<void> _addNewMedicationType() async {
    final TextEditingController nameController = TextEditingController();
    
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Medication'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Medication Name', 
            hintText: 'e.g. Vitamin D'
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      final String safeId = '${name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
      final newCategory = Category(
        id: safeId,
        name: name.trim(),
        iconName: 'medication',
        colorHex: '0xFFEF6C00', // Default Orange
      );

      setState(() {
        _medicationTypes.add(newCategory);
      });
      await CategoryManager().saveCategories('medication_types', _medicationTypes);
      
      // Immediately select to add entry
      if(mounted) _showDosageDialog(newCategory);
    }
  }

  Future<void> _deleteMedicationType(Category category) async {
    final defaults = ['melatonin', 'daridorexant', 'sertraline', 'lisdexamfetamine'];
    if (defaults.contains(category.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete default medication.")));
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Medication?"),
        content: Text("Remove '${category.name}' from your list?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _medicationTypes.removeWhere((c) => c.id == category.id);
      });
      await CategoryManager().saveCategories('medication_types', _medicationTypes);
    }
  }

  Future<void> _showDosageDialog(Category selectedType, {MedicationEntry? existingEntry, int? index}) async {
    String? dosage;
    Category currentDialogType = selectedType;
    DateTime selectedTime = existingEntry?.time ?? DateTime.now();

    // Check if we should show the dialog (editing OR no default dosage)
    bool showDialogInput = existingEntry != null || selectedType.defaultDosage == null;

    if (showDialogInput) {
      String initialDosage = existingEntry?.dosage ?? '';

      final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) {
              final controller = TextEditingController(text: initialDosage);
              DateTime tempTime = selectedTime;
              return StatefulBuilder(
                builder: (context, setStateDialog) {
                  return AlertDialog(
                      title: Text(existingEntry != null ? 'Edit Entry' : 'Enter Details'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Medication'),
                              initialValue: _medicationTypes.any((c) => c.id == currentDialogType.id) ? currentDialogType.id : null,
                              items: _medicationTypes.map((cat) {
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
                                    currentDialogType = _medicationTypes.firstWhere((c) => c.id == val);
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                autofocus: existingEntry == null && controller.text.isEmpty,
                                decoration: const InputDecoration(labelText: 'Dosage (mg/pill)', hintText: 'e.g. 5 or 10'),
                            ),
                            const SizedBox(height: 16),
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
                      ),
                      actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, {
                              'dosage': controller.text,
                              'type': currentDialogType,
                              'time': tempTime
                            }),
                            child: const Text('OK')
                          ),
                      ],
                  );
                }
              );
          }
      );

      if (result == null) return;
      dosage = result['dosage'];
      currentDialogType = result['type'];
      selectedTime = result['time'];
    } else {
      dosage = selectedType.defaultDosage.toString();
    }

    if (dosage == null) return;

    final newEntry = MedicationEntry(
      medicationTypeId: currentDialogType.id,
      dosage: dosage.isEmpty ? "Standard" : dosage,
      time: selectedTime
    );

    setState(() {
      if (index != null) {
        _log.medicationLog[index] = newEntry;
      } else {
        _log.medicationLog.add(newEntry);
      }
    });
    _saveLog();
  }

  Future<void> _showAddMedicationSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  const Text("Select Medication", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.5, 
                      ),
                      itemCount: _medicationTypes.length + 2,
                      itemBuilder: (context, index) {
                        if (index == _medicationTypes.length) {
                          return _MedicationTile(
                            label: "Add New...",
                            icon: Icons.add,
                            color: Colors.grey,
                            isOutline: true,
                            onTap: () {
                              Navigator.pop(context); 
                              _addNewMedicationType();
                            },
                          );
                        }
                        
                        if (index == _medicationTypes.length + 1) {
                           return _MedicationTile(
                            label: "Manage...",
                            icon: Icons.settings,
                            color: Colors.blueGrey,
                            isOutline: true,
                            onTap: () async {
                              Navigator.pop(context); 
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                              );
                              final medicationTypes = await CategoryManager().getCategories('medication_types');
                              setState(() {
                                _medicationTypes = medicationTypes;
                              });
                              if(mounted) _showAddMedicationSheet();
                            },
                          );
                        }

                        final cat = _medicationTypes[index];
                        return GestureDetector(
                          onLongPress: () {
                            Navigator.pop(context);
                            _deleteMedicationType(cat);
                          },
                          child: _MedicationTile(
                            label: cat.name, // Use just name here as dosage is separate
                            name: cat.name,
                            dosage: (cat.defaultDosage != null ? '${cat.defaultDosage} mg' : null),
                            icon: cat.icon,
                            color: cat.color,
                            onTap: () {
                              Navigator.pop(context);
                              _showDosageDialog(cat);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                      'Medication Entries',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_log.medicationLog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          "No medication logged yet.",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _log.medicationLog.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final category = _medicationTypes.where((c) => c.id == item.medicationTypeId).firstOrNull;
                        final displayName = category?.name ?? item.medicationTypeId;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: (category?.color ?? Colors.green).withAlpha(25),
                              child: Icon(category?.icon ?? Icons.medication_outlined, color: category?.color ?? Colors.green[800]),
                            ),
                            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("Dosage: ${item.dosage} mg \nTime: ${DateFormat('h:mm a').format(item.time)}"),
                            isThreeLine: true,
                            onTap: () {
                                final cat = category ?? Category(
                                  id: item.medicationTypeId, 
                                  name: item.medicationTypeId, 
                                  iconName: 'medication', 
                                  colorHex: '0xFFEF6C00'
                                );
                                _showDosageDialog(cat, existingEntry: item, index: index);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteMedicationEntry(index),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Medication'),
                    onPressed: _showAddMedicationSheet,
                  ),
                ],
              ),
            ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  final String label;
  final String? name;
  final String? dosage;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isOutline;

  const _MedicationTile({
    required this.label,
    this.name,
    this.dosage,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOutline ? Colors.transparent : color.withAlpha(25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOutline ? BorderSide(color: color, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: name != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name!,
                            style: TextStyle(
                              color: isOutline ? color : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dosage != null && dosage!.isNotEmpty)
                            Text(
                              dosage!,
                              style: TextStyle(
                                color: isOutline ? color : Theme.of(context).colorScheme.onSurface.withAlpha(179),
                                fontWeight: FontWeight.normal,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: isOutline ? color : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}