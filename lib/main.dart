import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';

// --- DATA STRUCTURE FOR MACRO AUTO CLEANER ---
class MacroModel {
  String id;
  String name;
  bool isEnabled;
  String triggerCategory;
  String triggerDetail;
  String actionCategory;
  String actionDetail;
  String constraintDetail;

  MacroModel({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.triggerCategory,
    required this.triggerDetail,
    required this.actionCategory,
    required this.actionDetail,
    this.constraintDetail = "None (Always Run)",
  });
}

// --- BACKGROUND WORKMANAGER DISPATCHER ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "macroAutoCleanTask") {
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final List<FileSystemEntity> entities = downloadsDir.listSync();
          for (var entity in entities) {
            await entity.delete(recursive: true);
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
  
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MacroAutoCleanerApp(),
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

// --- MAIN APPLICATION CLASS ---
class MacroAutoCleanerApp extends StatelessWidget {
  const MacroAutoCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Macro Auto Cleaner',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MacroAutoCleanerDashboard(),
    );
  }
}

// --- MAIN DASHBOARD SCREEN ---
class MacroAutoCleanerDashboard extends StatefulWidget {
  const MacroAutoCleanerDashboard({super.key});

  @override
  State<MacroAutoCleanerDashboard> createState() => _MacroAutoCleanerDashboardState();
}

class _MacroAutoCleanerDashboardState extends State<MacroAutoCleanerDashboard> {
  final List<MacroModel> _macros = [
    MacroModel(
      id: "1",
      name: "Daily Downloads Cleaner",
      triggerCategory: "Date / Time",
      triggerDetail: "Every 24 Hours Schedule",
      actionCategory: "File Operation",
      actionDetail: "Delete /Download Folder Contents",
      constraintDetail: "Only when Battery > 20%",
    ),
    MacroModel(
      id: "2",
      name: "Wi-Fi Storage Sentinel",
      triggerCategory: "Connectivity",
      triggerDetail: "Connected to Home Wi-Fi",
      actionCategory: "Notification / Alert",
      actionDetail: "Show Storage Warning Notification",
      constraintDetail: "Time between 8:00 AM - 10:00 PM",
    ),
    MacroModel(
      id: "3",
      name: "Shake to Clean Cache",
      triggerCategory: "Sensors / Motion",
      triggerDetail: "Device Shake Detected",
      actionCategory: "System Operations",
      actionDetail: "Clear Temp Cache Files",
      constraintDetail: "Device Unlocked",
    ),
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
      await Permission.notification.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Macro Auto Cleaner', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Row(
            children: [
              Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(value),
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
            // --- DASHBOARD TILES ---
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildDashboardTile(
                  title: 'Macros',
                  subtitle: '${_macros.length} Active',
                  icon: Icons.list_alt,
                  color: Colors.blueAccent,
                  onTap: () {},
                ),
                _buildDashboardTile(
                  title: 'Add Macro',
                  subtitle: 'Cleaner Wizard',
                  icon: Icons.add_circle_outline,
                  color: Colors.redAccent,
                  onTap: () => _showAddMacroWizard(),
                ),
                _buildDashboardTile(
                  title: 'Templates',
                  subtitle: 'Explore Presets',
                  icon: Icons.dashboard_customize,
                  color: Colors.orangeAccent,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cleaner Templates loaded!')),
                    );
                  },
                ),
                _buildDashboardTile(
                  title: 'Variables',
                  subtitle: 'Storage & System Info',
                  icon: Icons.code,
                  color: Colors.green,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- ACTIVE MACROS SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configured Cleaner Macros',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextChip(label: '${_macros.length} Active'),
              ],
            ),
            const SizedBox(height: 12),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _macros.length,
              itemBuilder: (context, index) {
                final macro = _macros[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              macro.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Switch(
                              value: macro.isEnabled,
                              onChanged: (val) {
                                setState(() {
                                  macro.isEnabled = val;
                                });
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildMacroBlock(
                          icon: Icons.bolt,
                          color: Colors.redAccent,
                          title: 'TRIGGER: ${macro.triggerCategory}',
                          subtitle: macro.triggerDetail,
                        ),
                        const SizedBox(height: 6),
                        _buildMacroBlock(
                          icon: Icons.play_arrow,
                          color: Colors.blueAccent,
                          title: 'ACTION: ${macro.actionCategory}',
                          subtitle: macro.actionDetail,
                        ),
                        const SizedBox(height: 6),
                        _buildMacroBlock(
                          icon: Icons.filter_alt,
                          color: Colors.green,
                          title: 'CONSTRAINT',
                          subtitle: macro.constraintDetail,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // --- FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMacroWizard(),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Cleaner Macro', style: TextStyle(color: Colors.white)),
      ),

      // --- DEVELOPER FOOTER ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Text(
          'Macro Auto Cleaner | Developed by Renante Fullo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDashboardTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroBlock({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMacroWizard() {
    String name = "";
    String selectedTriggerDetail = "Battery Level <= 20%";
    String selectedActionDetail = "Delete Downloads Folder";
    String selectedConstraint = "Only when connected to Wi-Fi";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Macro Auto Cleaner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Macro Name',
                        hintText: 'e.g. Auto Clean on Low Battery',
                      ),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Trigger', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedTriggerDetail,
                      items: const [
                        DropdownMenuItem(value: "Battery Level <= 20%", child: Text("Battery Level <= 20%")),
                        DropdownMenuItem(value: "Connected to Wi-Fi", child: Text("Connected to Wi-Fi")),
                        DropdownMenuItem(value: "Device Shake Motion", child: Text("Device Shake Motion")),
                        DropdownMenuItem(value: "Schedule: Every 24 Hours", child: Text("Schedule: Every 24 Hours")),
                      ],
                      onChanged: (val) => setDialogState(() => selectedTriggerDetail = val!),
                    ),
                    const SizedBox(height: 12),
                    const Text('Select Action', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedActionDetail,
                      items: const [
                        DropdownMenuItem(value: "Delete Downloads Folder", child: Text("Delete Downloads Folder")),
                        DropdownMenuItem(value: "Display Local Notification", child: Text("Display Local Notification")),
                        DropdownMenuItem(value: "Clear Temporary Cache", child: Text("Clear Temporary Cache")),
                      ],
                      onChanged: (val) => setDialogState(() => selectedActionDetail = val!),
                    ),
                    const SizedBox(height: 12),
                    const Text('Select Constraint', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedConstraint,
                      items: const [
                        DropdownMenuItem(value: "Only when connected to Wi-Fi", child: Text("Only when connected to Wi-Fi")),
                        DropdownMenuItem(value: "Time between 8 AM - 10 PM", child: Text("Time between 8 AM - 10 PM")),
                        DropdownMenuItem(value: "None (Always Run)", child: Text("None (Always Run)")),
                      ],
                      onChanged: (val) => setDialogState(() => selectedConstraint = val!),
                    ),
                  ],
                ),
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
                        _macros.add(
                          MacroModel(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: name,
                            triggerCategory: "Hardware / Event",
                            triggerDetail: selectedTriggerDetail,
                            actionCategory: "Storage Operation",
                            actionDetail: selectedActionDetail,
                            constraintDetail: selectedConstraint,
                          ),
                        );
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
      },
    );
  }
}

class TextChip extends StatelessWidget {
  final String label;
  const TextChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}