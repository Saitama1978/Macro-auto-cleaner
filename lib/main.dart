import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';

// --- BACKGROUND WORKMANAGER TASK ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "autoCleanTask") {
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final List<FileSystemEntity> entities = downloadsDir.listSync();
          for (var entity in entities) {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          }
        }
      } catch (e) {
        debugPrint("Background cleanup error: $e");
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize WorkManager for background automation
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const AutoCleanApp(),
    ),
  );
}

// --- THEME PROVIDER (DARK / LIGHT MODE) ---
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  void toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  void _loadThemeFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }
}

// --- MAIN APPLICATION ---
class AutoCleanApp extends StatelessWidget {
  const AutoCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'AutoClean Automation',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainHomeScreen(),
    );
  }
}

// --- MAIN HOME SCREEN ---
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final List<Map<String, String>> _activeMacros = [
    {
      "title": "Daily Downloads Cleaner",
      "trigger": "Schedule: Every 24 Hours",
      "action": "Delete all files in /Download"
    },
    {
      "title": "Clear Temp Files on Boot",
      "trigger": "Event: Device Boot Up",
      "action": "Clear App Cache & Temp Files"
    }
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _manualCleanDownloads() async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final List<FileSystemEntity> entities = downloadsDir.listSync();
        int deletedCount = 0;
        for (var entity in entities) {
          await entity.delete(recursive: true);
          deletedCount++;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nalinis na! $deletedCount files/folders ang nabura.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hindi nahanap ang Downloads folder.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Kailangan ng Storage Permission ($e)')),
        );
      }
    }
  }

  void _scheduleDailyCleaner() {
    Workmanager().registerPeriodicTask(
      "1",
      "autoCleanTask",
      frequency: const Duration(hours: 24),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Naka-schedule na ang auto-clean araw-araw!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoClean & Automation'),
        actions: [
          Row(
            children: [
              Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme(value);
                },
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ACTION BUTTONS ---
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(45),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('BURAHIN ANG DOWNLOADS NGAYON'),
                      onPressed: _manualCleanDownloads,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(45),
                      ),
                      icon: const Icon(Icons.schedule),
                      label: const Text('I-AUTOMATE ARAW-ARAW (WorkManager)'),
                      onPressed: _scheduleDailyCleaner,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- MACROS LIST SECTION ---
            const Text(
              'Active Automation Macros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeMacros.length,
              itemBuilder: (context, index) {
                final macro = _activeMacros[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.bolt),
                    ),
                    title: Text(macro['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Trigger: ${macro['trigger']}\nAction: ${macro['action']}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _activeMacros.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // --- ADD MACRO FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddMacroDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Macro'),
      ),

      // --- DEVELOPER FOOTER ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Text(
          'Developer: Renante Fullo | Open-Source Automation Engine',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  void _showAddMacroDialog() {
    String name = "";
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gumawa ng Bagong Macro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Macro Name'),
                onChanged: (val) => name = val,
              ),
              const SizedBox(height: 10),
              const ListTile(
                leading: Icon(Icons.input),
                title: Text('Trigger'),
                subtitle: Text('Default: Daily Timer (24h)'),
              ),
              const ListTile(
                leading: Icon(Icons.play_arrow),
                title: Text('Action'),
                subtitle: Text('Default: Delete Downloads Folder'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  setState(() {
                    _activeMacros.add({
                      "title": name,
                      "trigger": "Schedule: Daily",
                      "action": "Delete Downloads Folder"
                    });
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Save Macro'),
            ),
          ],
        );
      },
    );
  }
}
