import 'package:flutter/material.dart';
import '../log_service.dart';
import '../app.dart'; // To access themeNotifier
import 'category_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.settings_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'App Settings',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // --- DARK MODE TOGGLE ---
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, child) {
                  final isDark = mode == ThemeMode.dark;
                  return Card(
                    child: SwitchListTile(
                      title: const Text("Dark Mode"),
                      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                      value: isDark,
                      activeColor: Colors.indigoAccent,
                      onChanged: (val) {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        LogService().setDarkMode(val);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'All your log data is saved locally on this device. Clearing data is permanent and cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              // --- CATEGORIES MANAGEMENT BUTTON ---
              ElevatedButton.icon(
                icon: const Icon(Icons.category_outlined),
                label: const Text('Manage Categories'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- CSV EXPORT BUTTON (Reverted) ---
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export Data as CSV'),
                onPressed: () async {
                  await LogService().exportToCsv(context);
                },
              ),
              const SizedBox(height: 10),

              // --- CSV IMPORT BUTTON ---
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Data from CSV'),
                onPressed: () async {
                   await LogService().importFromCsv(context);
                },
              ),
              const SizedBox(height: 20),
              
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Clear All Saved Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                ),
                onPressed: () async {
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Are you sure?'),
                      content:
                          const Text('This will delete all saved data permanently.'),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await LogService().clearAllData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('All saved data has been cleared!')),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}