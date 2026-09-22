import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/local/local_prefs.dart';
import '../../../core/theme/app_theme.dart';

const _savedAddressesKey = 'customer.saved_addresses';

class SavedAddress {
  const SavedAddress({
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    label: json['label'] as String,
    address: json['address'] as String,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );

  final String label;
  final String address;

  /// Set when this entry was saved from a map pin (Post a Job's route
  /// picker) rather than typed by hand on this screen — lets a future
  /// quick-fill jump straight to the point instead of re-geocoding the
  /// address text. Null for addresses saved the old way.
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };
}

/// Reads the current saved-address book — used by this screen itself and
/// by anywhere else in the app that wants to offer them as quick-fill
/// options (e.g. Post a Job's route picker map).
Future<List<SavedAddress>> loadSavedAddresses({
  LocalPrefs prefs = const LocalPrefs(),
}) async {
  final raw = await prefs.getStringList(_savedAddressesKey);
  return raw
      .map((s) => SavedAddress.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();
}

/// Adds a new saved address from anywhere in the app, not just this
/// screen's own FAB — enforces the same free-tier cap (with the same
/// upsell message) and shows the same add dialog, optionally pre-filled
/// with an address/coordinates already known to the caller (e.g. the pin
/// a customer just placed on Post a Job's map). Returns whether an
/// address was actually added.
Future<bool> addSavedAddress({
  required BuildContext context,
  required bool isFeatured,
  String? initialAddress,
  double? lat,
  double? lng,
  LocalPrefs prefs = const LocalPrefs(),
}) async {
  final raw = await prefs.getStringList(_savedAddressesKey);
  if (!isFeatured && raw.length >= _freeAddressCap) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Standard accounts can save up to 3 addresses. Get Cargo Motives Plus to save more.',
          ),
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final added = await showDialog<SavedAddress>(
    context: context,
    builder: (_) =>
        AddSavedAddressDialog(initialAddress: initialAddress, lat: lat, lng: lng),
  );
  if (added == null) return false;

  await prefs.setStringList(_savedAddressesKey, [
    ...raw,
    jsonEncode(added.toJson()),
  ]);
  return true;
}

/// "Saved addresses" — real on-device persistence via SharedPreferences
/// (LocalPrefs), not synced to any backend: a customer's entries here
/// live only on this device. Also offered as quick-fill chips on Post a
/// Job's route map (see [loadSavedAddresses]/[addSavedAddress] above),
/// which can add entries here too when a customer saves a pin they just
/// dropped — this screen is just the one place to browse/delete them all.
///
/// Customer Plus benefit (Phase 10.19): a standard customer is capped at
/// [_freeAddressCap] entries; Plus removes the cap — a real, on-device
/// limit rather than a cosmetic one, since this feature already has no
/// backend to gate against instead.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({
    super.key,
    this.isFeatured = false,
    this.prefs = const LocalPrefs(),
  });

  final bool isFeatured;
  final LocalPrefs prefs;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

const _freeAddressCap = 3;

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final addresses = await loadSavedAddresses(prefs: widget.prefs);
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await widget.prefs.setStringList(
      _savedAddressesKey,
      _addresses.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> _addAddress() async {
    final added = await addSavedAddress(
      context: context,
      isFeatured: widget.isFeatured,
      prefs: widget.prefs,
    );
    if (added) await _load();
  }

  Future<void> _removeAddress(int index) async {
    setState(() => _addresses = [..._addresses]..removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        bottom: widget.isFeatured
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_addresses.length} of $_freeAddressCap · Plus removes the limit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAddress,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SizedBox(height: 80),
                Icon(
                  Icons.place_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: 16),
                Text(
                  'No saved addresses yet. Tap + to add one.',
                  textAlign: TextAlign.center,
                ),
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
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.place_outlined,
                          size: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.label,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              address.address,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _removeAddress(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AddSavedAddressDialog extends StatefulWidget {
  const AddSavedAddressDialog({
    super.key,
    this.initialAddress,
    this.lat,
    this.lng,
  });

  final String? initialAddress;
  final double? lat;
  final double? lng;

  @override
  State<AddSavedAddressDialog> createState() => _AddSavedAddressDialogState();
}

class _AddSavedAddressDialogState extends State<AddSavedAddressDialog> {
  final _labelController = TextEditingController();
  late final _addressController = TextEditingController(
    text: widget.initialAddress ?? '',
  );

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
            decoration: const InputDecoration(
              labelText: 'Label (e.g. Warehouse, Home)',
            ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_labelController.text.trim().isEmpty ||
                _addressController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              SavedAddress(
                label: _labelController.text.trim(),
                address: _addressController.text.trim(),
                lat: widget.lat,
                lng: widget.lng,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
