import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../log_service.dart';
import '../app.dart'; 
import 'category_management_screen.dart';
import '../notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LogService _logService = LogService();
  bool _isNotifEnabled = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _isNotifEnabled = _logService.areNotificationsEnabled;
    _userName = _logService.userName;
  }

  Future<void> _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/papaang/Project_Impactive_Sleep_Tracker_App');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
        }
      }
    } catch (e) {
      // In case package is missing or platform error
      // debugPrint('Could not launch URL: $e');
    }
  }

   Future<void> _updateUserName() async {
    final TextEditingController controller = TextEditingController(text: _userName);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Your Alias"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. SleepyHead"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text), 
            child: const Text("Save")
          ),
        ],
      )
    );

    if (newName != null) {
      await _logService.setUserName(newName);
      setState(() => _userName = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
              const SizedBox(height: 8),
              // --- VERSION TAG ---
              Container(
                alignment: Alignment.center,
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, child) {
                    final isDark = mode == ThemeMode.dark;
                    return Chip(
                      label: const Text("Version 2.0.3"), //change that when updating
                      backgroundColor: Colors.indigo.withAlpha(25),
                      labelStyle: TextStyle(color: (isDark ? Colors.indigo[200] : Colors.indigo[800]), fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

               // --- USER ALIAS ---
              Card(
                child: ListTile(
                  title: const Text("User Alias"),
                  subtitle: Text(_userName.isEmpty ? "Tap to set name" : _userName),
                  leading: const Icon(Icons.person),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: _updateUserName,
                ),
              ),

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
                      activeThumbColor: Colors.indigoAccent,
                      onChanged: (val) {
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        LogService().setDarkMode(val);
                      },
                    ),
                  );
                },
              ),

              // --- NOTIFICATION TOGGLE ---
              Card(
                child: SwitchListTile(
                  title: const Text("Notification Controls"),
                  subtitle: const Text("Show Add Meds/Sleep in notification bar"),
                  secondary: const Icon(Icons.notifications_active_outlined),
                  value: _isNotifEnabled,
                  activeThumbColor: Colors.indigoAccent,
                  onChanged: (val) async {
                    setState(() => _isNotifEnabled = val);
                    await _logService.setNotificationsEnabled(val);
                    if (val) {
                      NotificationService().showPersistentControls(isSleeping: false);
                    } else {
                      NotificationService().cancelAll();
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),
              
              // --- CATEGORIES MANAGEMENT ---
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
              const SizedBox(height: 12),

              // --- CSV EXPORT ---
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export Data as CSV'),
                onPressed: () async {
                  await LogService().exportToCsv(context);
                },
              ),
              const SizedBox(height: 12),

              // --- CSV IMPORT ---
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Data from CSV'),
                onPressed: () async {
                   await LogService().importFromCsv(context);
                },
              ),
              const SizedBox(height: 12),

              // --- GITHUB LINK ---
              OutlinedButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('Visit GitHub Repo'),
                onPressed: _launchGitHub,
              ),

              const SizedBox(height: 20),
              
              // --- CLEAR DATA ---
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
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}