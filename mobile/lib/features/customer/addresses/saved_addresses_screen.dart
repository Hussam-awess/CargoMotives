import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/local/local_prefs.dart';
import '../../../core/theme/app_theme.dart';

const _savedAddressesKey = 'customer.saved_addresses';

class SavedAddress {
  const SavedAddress({required this.label, required this.address});

  factory SavedAddress.fromJson(Map<String, dynamic> json) =>
      SavedAddress(label: json['label'] as String, address: json['address'] as String);

  final String label;
  final String address;

  Map<String, dynamic> toJson() => {'label': label, 'address': address};
}

/// "Saved addresses" (mockup) — real on-device persistence via
/// SharedPreferences (LocalPrefs), not synced to any backend: this app
/// has no saved-address-book feature yet, so a customer's entries here
/// live only on this device. Post a Job still takes a fresh address each
/// time; wiring a saved address into that form as a quick-fill shortcut
/// is a natural next step once this list has something in it worth
/// reusing.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, this.prefs = const LocalPrefs()});

  final LocalPrefs prefs;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await widget.prefs.getStringList(_savedAddressesKey);
    if (!mounted) return;
    setState(() {
      _addresses = raw.map((s) => SavedAddress.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await widget.prefs.setStringList(_savedAddressesKey, _addresses.map((a) => jsonEncode(a.toJson())).toList());
  }

  Future<void> _addAddress() async {
    final added = await showDialog<SavedAddress>(context: context, builder: (_) => const _AddAddressDialog());
    if (added == null) return;
    setState(() => _addresses = [..._addresses, added]);
    await _save();
  }

  Future<void> _removeAddress(int index) async {
    setState(() => _addresses = [..._addresses]..removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      floatingActionButton: FloatingActionButton(onPressed: _addAddress, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 80),
                Icon(Icons.place_outlined, size: 48, color: AppColors.textTertiary),
                SizedBox(height: 16),
                Text('No saved addresses yet. Tap + to add one.', textAlign: TextAlign.center),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final address = _addresses[index];
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(7)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.place_outlined, size: 17, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(address.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            Text(address.address, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _removeAddress(index)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label (e.g. Warehouse, Home)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_labelController.text.trim().isEmpty || _addressController.text.trim().isEmpty) return;
            Navigator.of(context).pop(SavedAddress(label: _labelController.text.trim(), address: _addressController.text.trim()));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
