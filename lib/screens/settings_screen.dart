import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box<List<String>> settingsBox;
  List<String> allowedAddresses = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // We assume the box is already open in main or we open it here safely
    if (!Hive.isBoxOpen('settings')) {
      settingsBox = await Hive.openBox<List<String>>('settings');
    } else {
      settingsBox = Hive.box<List<String>>('settings');
    }

    setState(() {
      allowedAddresses =
          settingsBox.get('allowed_addresses', defaultValue: ['16216']) ??
          ['16216'];
    });
  }

  Future<void> _addAddress(String address) async {
    if (address.isEmpty) return;
    if (allowedAddresses.contains(address)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Address already exists")));
      return;
    }

    setState(() {
      allowedAddresses.add(address);
    });
    await settingsBox.put('allowed_addresses', allowedAddresses);
    _controller.clear();
  }

  Future<void> _removeAddress(String address) async {
    setState(() {
      allowedAddresses.remove(address);
    });
    await settingsBox.put('allowed_addresses', allowedAddresses);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: "Add Sender Address",
                      hintText: "e.g. 16216 or BANKNA",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addAddress(_controller.text.trim()),
                  child: const Text("Add"),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: allowedAddresses.length,
              itemBuilder: (context, index) {
                final address = allowedAddresses[index];
                return ListTile(
                  title: Text(address),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeAddress(address),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
