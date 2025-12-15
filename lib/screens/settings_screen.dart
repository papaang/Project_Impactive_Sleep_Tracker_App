import 'package:flutter/material.dart';
import '../log_service.dart';
import 'category_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
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
              const SizedBox(height: 20),
              Text(
                'All your log data is saved locally on this device. Clearing data is permanent and cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              
              // --- CATEGORIES MANAGEMENT BUTTON ---
              ElevatedButton.icon(
                icon: Icon(Icons.category_outlined),
                label: const Text('Manage Categories'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // --- CSV EXPORT BUTTON ---
              ElevatedButton.icon(
                icon: Icon(Icons.download),
                label: const Text('Export Data as CSV'),
                onPressed: () async {
                  await LogService().exportToCsv(context);
                },
              ),
              const SizedBox(height: 20),
              
              OutlinedButton.icon(
                icon: Icon(Icons.delete_forever_outlined),
                label: const Text('Clear All Saved Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[700]!),
                ),
                onPressed: () async {
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Are you sure?'),
                      content:
                          Text('This will delete all saved data permanently.'),
                      actions: [
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: Text('Delete',
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
                        SnackBar(
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
