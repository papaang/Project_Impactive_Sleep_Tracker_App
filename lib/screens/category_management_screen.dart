import 'package:flutter/material.dart';
import '../models.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<Category>> _categories = {};
  final List<String> _categoryTypes = ['day_types', 'sleep_locations', 'medication_types', 'exercise_types', 'substance_types'];
  final List<String> _categoryTypeName = ['Day Type', 'Sleep Location', 'Medication Type', 'Exercise Type', 'Substance Type'];
  final List<String> _categoryTypeNames = ['Day Types', 'Sleep Locations', 'Medication Types', 'Exercise Types', 'Substance Types'];

  static const Map<String, String> iconDisplayNames = {
    'work_outline': 'Work',
    'self_improvement_outlined': 'Self Improvement',
    'explore_outlined': 'Explore',
    'people_outline': 'People',
    'bed': 'Bed',
    'weekend': 'Weekend',
    'directions_car': 'Car',
    'medication': 'Medication',
    'directions_walk': 'Walk',
    'directions_run': 'Run',
    'fitness_center': 'Fitness',
    'coffee': 'Coffee',
    'emoji_food_beverage': 'Food & Beverage',
    'local_drink': 'Drink',
    'wine_bar': 'Wine',
    'wb_sunny_outlined': 'Sunny',
  };

  static const Map<String, String> colorDisplayNames = {
    '0xFF1565C0': 'Blue',
    '0xFF2E7D32': 'Green',
    '0xFFEF6C00': 'Orange',
    '0xFF7B1FA2': 'Purple',
    '0xFF424242': 'Grey',
    '0xFF4CAF50': 'Light Green',
    '0xFFFF9800': 'Light Orange',
    '0xFFF44336': 'Red',
    '0xFF795548': 'Brown',
    '0xFFFFC0CB': 'Pink',
    '0xFF000000': 'Black',
    '0xFF607D8B': 'Blue Grey',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryTypes.length, vsync: this);
    _loadCategories();
    _tabController.addListener(() => setState(() {}));
  }

  Future<void> _loadCategories() async {
    final dayTypes = await CategoryManager().getCategories('day_types');
    final sleepLocations = await CategoryManager().getCategories('sleep_locations');
    final medicationTypes = await CategoryManager().getCategories('medication_types');
    final exerciseTypes = await CategoryManager().getCategories('exercise_types');
    final substanceTypes = await CategoryManager().getCategories('substance_types');
    setState(() {
      _categories = {
        'day_types': dayTypes,
        'sleep_locations': sleepLocations,
        'medication_types': medicationTypes,
        'exercise_types': exerciseTypes,
        'substance_types': substanceTypes,
      };
    });
  }

  Future<void> _showAddEditDialog(String categoryType, {Category? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category.name : '');
    String selectedIcon = isEdit ? category.iconName : 'work_outline';
    String selectedColor = isEdit ? category.colorHex : '0xFF1565C0';
    final dosageController = TextEditingController(text: isEdit && category.defaultDosage != null ? category.defaultDosage.toString() : '');

    // Defaults for specific types if not editing
    if (!isEdit) {
       if (categoryType == 'medication_types') { selectedIcon = 'medication'; selectedColor = '0xFFEF6C00'; }
       else if (categoryType == 'exercise_types') { selectedIcon = 'fitness_center'; selectedColor = '0xFF4CAF50'; }
       else if (categoryType == 'substance_types') { selectedIcon = 'local_drink'; selectedColor = '0xFF795548'; }
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedIcon, // Changed from initialValue to value to reflect updates
                items: [
                  'work_outline',
                  'self_improvement_outlined',
                  'explore_outlined',
                  'people_outline',
                  'bed',
                  'weekend',
                  'directions_car',
                  'medication',
                  'directions_walk',
                  'directions_run',
                  'fitness_center',
                  'coffee',
                  'emoji_food_beverage',
                  'local_drink',
                  'wine_bar',
                  'wb_sunny_outlined',
                ].map((icon) => DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(Category(id: 'dummy', iconName: icon, name: '', colorHex: '0xFF000000').icon),
                      const SizedBox(width: 8),
                      Text(iconDisplayNames[icon] ?? icon),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => selectedIcon = value!,
                decoration: const InputDecoration(labelText: 'Icon'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedColor, // Changed from initialValue to value
                items: [
                  '0xFF1565C0', // blue
                  '0xFF2E7D32', // green
                  '0xFFEF6C00', // orange
                  '0xFF7B1FA2', // purple
                  '0xFF424242', // grey
                  '0xFF4CAF50', // light green
                  '0xFFFF9800', // light orange
                  '0xFFF44336', // red
                  '0xFF795548', // brown
                  '0xFFFFC0CB', // pink
                  '0xFF000000', // black
                  '0xFF607D8B', // blue grey
                ].map((color) => DropdownMenuItem(
                  value: color,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        color: Color(int.parse(color)),
                      ),
                      const SizedBox(width: 8),
                      Text(colorDisplayNames[color] ?? color),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => selectedColor = value!,
                decoration: const InputDecoration(labelText: 'Color'),
              ),
              if (categoryType == 'medication_types') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: dosageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Default Dosage (mg, optional)'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              final resultMap = {
                'name': nameController.text,
                'iconName': selectedIcon,
                'colorHex': selectedColor,
              };
              if (categoryType == 'medication_types' && dosageController.text.isNotEmpty) {
                resultMap['defaultDosage'] = dosageController.text;
              }
              Navigator.pop(context, resultMap);
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      // Parse default dosage to int?
      int? defDosage;
      if (result['defaultDosage'] != null && result['defaultDosage']!.trim().isNotEmpty) {
        defDosage = int.tryParse(result['defaultDosage']!);
      }

      if (isEdit) {
        // Edit existing
        final updated = Category(
          id: category.id,
          name: result['name']!,
          iconName: result['iconName']!,
          colorHex: result['colorHex']!,
          defaultDosage: defDosage,
        );
        final index = _categories[categoryType]!.indexWhere((c) => c.id == category.id);
        if (index != -1) {
          _categories[categoryType]![index] = updated;
          await CategoryManager().saveCategories(categoryType, _categories[categoryType]!);
          setState(() {});
        }
      } else {
        // Add new
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final newCategory = Category(
          id: newId,
          name: result['name']!,
          iconName: result['iconName']!,
          colorHex: result['colorHex']!,
          defaultDosage: defDosage,
        );
        _categories[categoryType]!.add(newCategory);
        await CategoryManager().saveCategories(categoryType, _categories[categoryType]!);
        setState(() {});
      }
    }
  }

  Future<void> _deleteCategory(String categoryType, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      _categories[categoryType]!.removeWhere((c) => c.id == category.id);
      await CategoryManager().saveCategories(categoryType, _categories[categoryType]!);
      setState(() {});
    }
  }

  Future<void> _resetCategories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Categories'),
        content: const Text('Are you sure you want to reset all categories to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Define default categories (re-using definitions from models.dart/CategoryManager)
      // Ideally CategoryManager should have a public reset method, but implementing here for now.
      
      final defaultDayTypes = [
        Category(id: 'work', name: 'Work', iconName: 'work_outline', colorHex: '0xFF1565C0'),
        Category(id: 'relax', name: 'Relax', iconName: 'self_improvement_outlined', colorHex: '0xFF2E7D32'),
        Category(id: 'travel', name: 'Travel', iconName: 'explore_outlined', colorHex: '0xFFEF6C00'),
        Category(id: 'social', name: 'Social', iconName: 'people_outline', colorHex: '0xFF7B1FA2'),
      ];
      final defaultSleepLocations = [
        Category(id: 'bed', name: 'Bed', iconName: 'bed', colorHex: '0xFF1565C0'),
        Category(id: 'couch', name: 'Couch', iconName: 'weekend', colorHex: '0xFF2E7D32'),
        Category(id: 'in_transit', name: 'In Transit', iconName: 'directions_car', colorHex: '0xFFEF6C00'),
      ];
      final defaultMedicationTypes = [
        Category(id: 'melatonin', name: 'Melatonin', iconName: 'medication', colorHex: '0xFF2E7D32', defaultDosage: 50),
        Category(id: 'daridorexant', name: 'Daridorexant', iconName: 'medication', colorHex: '0xFF1565C0', defaultDosage: 50),
        Category(id: 'sertraline', name: 'Sertraline', iconName: 'medication', colorHex: '0xFF7B1FA2', defaultDosage: 50),
        Category(id: 'lisdexamfetamine', name: 'Lisdexamfetamine', iconName: 'medication', colorHex: '0xFFEF6C00', defaultDosage: 50),
      ];
      final defaultExerciseTypes = [
        Category(id: 'light', name: 'Light', iconName: 'directions_walk', colorHex: '0xFF4CAF50'),
        Category(id: 'medium', name: 'Medium', iconName: 'directions_run', colorHex: '0xFFFF9800'),
        Category(id: 'heavy', name: 'Heavy', iconName: 'fitness_center', colorHex: '0xFFF44336'),
      ];
       final defaultSubstanceTypes = [
        Category(id: 'caffeine', name: 'Caffeine', iconName: 'coffee', colorHex: '0xFF795548'),
        Category(id: 'alcohol', name: 'Alcohol', iconName: 'wine_bar', colorHex: '0xFF9C27B0'),
      ];

      await CategoryManager().saveCategories('day_types', defaultDayTypes);
      await CategoryManager().saveCategories('sleep_locations', defaultSleepLocations);
      await CategoryManager().saveCategories('medication_types', defaultMedicationTypes);
      await CategoryManager().saveCategories('exercise_types', defaultExerciseTypes);
      await CategoryManager().saveCategories('substance_types', defaultSubstanceTypes);

      await _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: _resetCategories,
            tooltip: 'Reset Categories',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _categoryTypeNames.map((name) => Tab(text: name)).toList(),
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categoryTypes.map((type) {
          final cats = _categories[type] ?? [];
          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              return ListTile(
                leading: Icon(cat.icon, color: cat.color), // Fixed: Use cat.color
                title: Text(cat.name + (cat.defaultDosage != null ? ' (${cat.defaultDosage} mg)' : '')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteCategory(type, cat),
                ),
                onTap: () => _showAddEditDialog(type, category: cat),
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text('New ${_categoryTypeName.length > _tabController.index ? _categoryTypeName[_tabController.index] : 'Category'}'),
        onPressed: () => _showAddEditDialog(_categoryTypes[_tabController.index]),
      ),
    );
  }
  
  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }
}