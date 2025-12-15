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
  final List<String> _categoryTypes = ['day_types', 'sleep_locations', 'medication_types'];
  final List<String> _categoryTypeName = ['Day Type', 'Sleep Location', 'Medication Type'];
  final List<String> _categoryTypeNames = ['Day Types', 'Sleep Locations', 'Medication Types'];
  // final List<String> _categoryTypes = ['day_types', 'sleep_locations', 'medication_types', 'exercise_types'];
  // final List<String> _categoryTypeName = ['Day Type', 'Sleep Location', 'Medication Type', 'Exercise Type'];
  // final List<String> _categoryTypeNames = ['Day Types', 'Sleep Locations', 'Medication Types', 'Exercise Types'];

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
    // final exerciseTypes = await CategoryManager().getCategories('exercise_types');
    setState(() {
      _categories = {
        'day_types': dayTypes,
        'sleep_locations': sleepLocations,
        'medication_types': medicationTypes,
        // 'exercise_types': exerciseTypes,
      };
    });
  }

  Future<void> _showAddEditDialog(String categoryType, {Category? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category.name : '');
    String selectedIcon = isEdit ? category.iconName : 'work_outline';
    String selectedColor = isEdit ? category.colorHex : '0xFF1565C0';

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
                decoration: InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedIcon,
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
                ].map((icon) => DropdownMenuItem(
                  value: icon,
                  child: Row(
                    children: [
                      Icon(Category(id: 'dummy', iconName: icon, name: '', colorHex: '0xFF000000').icon),
                      const SizedBox(width: 8),
                      Text(icon),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => selectedIcon = value!,
                decoration: InputDecoration(labelText: 'Icon'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedColor,
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
                  '0xFF9C27B0', // pink
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
                      Text(color),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => selectedColor = value!,
                decoration: InputDecoration(labelText: 'Color'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;
              Navigator.pop(context, {
                'name': nameController.text,
                'iconName': selectedIcon,
                'colorHex': selectedColor,
              });
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      if (isEdit) {
        // Edit existing
        final updated = Category(
          id: category.id,
          name: result['name']!,
          iconName: result['iconName']!,
          colorHex: result['colorHex']!,
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
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _categories[categoryType]!.removeWhere((c) => c.id == category.id);
      await CategoryManager().saveCategories(categoryType, _categories[categoryType]!);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _categoryTypeNames.map((name) => Tab(text: name)).toList(),
          unselectedLabelColor: Color(0xffDDDADA),
          labelColor: Color(0xffDDDADA),
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
                leading: Icon(cat.icon, color: cat.materialColor),
                title: Text(cat.name),
                trailing: IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _deleteCategory(type, cat),
                ),
                onTap: () => _showAddEditDialog(type, category: cat),
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.add),
        label: Text('New ${_categoryTypeName[_tabController.index]}'),
        onPressed: () => _showAddEditDialog(_categoryTypes[_tabController.index]),
      ),
    );
  }
  @override
  void dispose() {
    _tabController.removeListener(() {});
    super.dispose();
  }
}
