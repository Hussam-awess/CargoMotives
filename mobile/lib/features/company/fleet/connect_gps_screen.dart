import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/gps_repository.dart';
import '../data/truck_repository.dart';
import 'gps_connection_guide_screen.dart';

enum GpsProviderOption {
  wialon('wialon', 'Wialon'),
  traccar('traccar', 'Traccar'),
  tracksolidPro('tracksolid_pro', 'Tracksolid Pro');

  const GpsProviderOption(this.value, this.label);

  /// The exact string the backend's gps_connections.provider column and
  /// ConnectGpsRequest expect.
  final String value;
  final String label;

  /// The display label for a raw provider value (Truck.gpsProvider) —
  /// used wherever a truck shows which provider it's imported from,
  /// outside this screen's own provider-picker UI. Falls back to the raw
  /// value itself for anything unrecognized, rather than guessing wrong.
  static String labelFor(String value) {
    for (final option in GpsProviderOption.values) {
      if (option.value == value) return option.label;
    }
    return value;
  }
}

/// Connect GPS (AppFlow §2.3): pick a provider, authorize with an access
/// token, then match each returned vehicle to a registered truck (or skip
/// it — an unmatched vehicle just stays "GPS Tracking Not Available",
/// same as if the company never connected anything at all). All three
/// providers are real integrations now (Wialon, then Traccar and
/// Tracksolid Pro added alongside it once the pattern was proven).
///
/// Tracksolid Pro needs four credentials (see TracksolidGpsProvider's own
/// docblock on the backend) rather than the one token Wialon/Traccar use —
/// still entered as a single pasted string here, joined by colons:
/// `appKey:appSecret:account:userPwdMd5`.
class ConnectGpsScreen extends StatefulWidget {
  ConnectGpsScreen({
    super.key,
    GpsRepository? gpsRepository,
    TruckRepository? truckRepository,
  }) : gpsRepository = gpsRepository ?? GpsRepository(),
       truckRepository = truckRepository ?? TruckRepository();

  final GpsRepository gpsRepository;
  final TruckRepository truckRepository;

  @override
  State<ConnectGpsScreen> createState() => _ConnectGpsScreenState();
}

/// A sentinel stored in `_selectedTruckIdByUnit` alongside real truck ids
/// and null (skip) — chosen well outside any real truck id's range so it
/// can share that same map instead of a second piece of per-unit state.
const _createNewSentinel = -1;

class _ConnectGpsScreenState extends State<ConnectGpsScreen> {
  final _tokenController = TextEditingController();
  GpsProviderOption _selectedProvider = GpsProviderOption.wialon;
  bool _isConnecting = false;
  String? _connectError;

  GpsConnectionSummary? _connection;
  List<GpsUnitCandidate> _units = [];
  List<Truck> _availableTrucks = [];
  final Map<String, int?> _selectedTruckIdByUnit = {};
  bool _isImporting = false;
  String? _importError;
  List<Truck>? _importedTrucks;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(
        () =>
            _connectError = 'Enter your ${_selectedProvider.label} API token.',
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectError = null;
    });

    try {
      final result = await widget.gpsRepository.connect(
        provider: _selectedProvider.value,
        accessToken: token,
      );
      final trucks = await widget.truckRepository.list();
      if (!mounted) return;
      setState(() {
        _connection = result.connection;
        _units = result.units;
        _availableTrucks = trucks
            .where((t) => t.gpsStatus != 'connected')
            .toList();
        for (final unit in result.units) {
          _selectedTruckIdByUnit[unit.unitId] = unit.suggestedTruckId;
        }
      });
    } on ApiException catch (e) {
      setState(
        () => _connectError = e.firstErrorFor('access_token') ?? e.message,
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _import() async {
    final unitsByid = {for (final unit in _units) unit.unitId: unit};
    final matches = <GpsUnitMatch>[
      for (final entry in _selectedTruckIdByUnit.entries)
        if (entry.value == _createNewSentinel)
          GpsUnitMatch.createNew(
            unitId: entry.key,
            unitName: unitsByid[entry.key]!.name,
          )
        else if (entry.value != null)
          GpsUnitMatch.existing(unitId: entry.key, truckId: entry.value!),
    ];

    if (matches.isEmpty) {
      setState(
        () => _importError =
            'Match at least one vehicle to a truck, or go back if none apply.',
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    try {
      final trucks = await widget.gpsRepository.import(
        connectionId: _connection!.id,
        matches: matches,
      );
      if (!mounted) return;
      setState(() => _importedTrucks = trucks);
    } on ApiException catch (e) {
      setState(() => _importError = e.message);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect GPS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _importedTrucks != null
            ? _ImportedSummary(
                trucks: _importedTrucks!,
                onDone: () => Navigator.of(context).pop(true),
              )
            : _connection == null
            ? _ProviderForm(
                tokenController: _tokenController,
                selectedProvider: _selectedProvider,
                onSelectProvider: (provider) =>
                    setState(() => _selectedProvider = provider),
                isConnecting: _isConnecting,
                error: _connectError,
                onConnect: _connect,
              )
            : _MatchUnitsForm(
                providerLabel: _selectedProvider.label,
                units: _units,
                availableTrucks: _availableTrucks,
                selectedTruckIdByUnit: _selectedTruckIdByUnit,
                onSelect: (unitId, truckId) =>
                    setState(() => _selectedTruckIdByUnit[unitId] = truckId),
                isImporting: _isImporting,
                error: _importError,
                onImport: _import,
              ),
      ),
    );
  }
}

class _ProviderForm extends StatelessWidget {
  const _ProviderForm({
    required this.tokenController,
    required this.selectedProvider,
    required this.onSelectProvider,
    required this.isConnecting,
    required this.error,
    required this.onConnect,
  });

  final TextEditingController tokenController;
  final GpsProviderOption selectedProvider;
  final void Function(GpsProviderOption provider) onSelectProvider;
  final bool isConnecting;
  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final isTracksolid = selectedProvider == GpsProviderOption.tracksolidPro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose your provider',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GpsConnectionGuideScreen(),
              ),
            ),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Step-by-step guide'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 8),
        for (final provider in GpsProviderOption.values) ...[
          _ProviderTile(
            provider: provider,
            selected: provider == selectedProvider,
            onTap: () => onSelectProvider(provider),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        if (isTracksolid) ...[
          Text(
            'Tracksolid Pro needs four credentials joined with colons: appKey:appSecret:account:userPwdMd5.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: tokenController,
          decoration: InputDecoration(
            labelText: '${selectedProvider.label} API token',
          ),
          obscureText: true,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isConnecting ? null : onConnect,
          child: isConnecting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final GpsProviderOption provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? AppColors.infoTint : null,
      child: ListTile(
        title: Text(provider.label),
        trailing: selected
            ? Icon(Icons.check_circle, color: AppColors.ctaBlue)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _MatchUnitsForm extends StatelessWidget {
  const _MatchUnitsForm({
    required this.providerLabel,
    required this.units,
    required this.availableTrucks,
    required this.selectedTruckIdByUnit,
    required this.onSelect,
    required this.isImporting,
    required this.error,
    required this.onImport,
  });

  final String providerLabel;
  final List<GpsUnitCandidate> units;
  final List<Truck> availableTrucks;
  final Map<String, int?> selectedTruckIdByUnit;
  final void Function(String unitId, int? truckId) onSelect;
  final bool isImporting;
  final String? error;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '✓ $providerLabel connected',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.statusLive),
        ),
        const SizedBox(height: 4),
        Text(
          'We found ${units.length} vehicle(s)',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final unit in units) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (!unit.hasPosition)
                          Text(
                            'No position reported yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DropdownButton<int?>(
                    value: selectedTruckIdByUnit[unit.unitId],
                    hint: const Text('Skip'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Skip'),
                      ),
                      const DropdownMenuItem<int?>(
                        value: _createNewSentinel,
                        child: Text('Add as new truck'),
                      ),
                      for (final truck in availableTrucks)
                        DropdownMenuItem<int?>(
                          value: truck.id,
                          child: Text(truck.registrationNumber),
                        ),
                    ],
                    onChanged: (truckId) => onSelect(unit.unitId, truckId),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isImporting ? null : onImport,
          child: isImporting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Import selected vehicles'),
        ),
      ],
    );
  }
}

class _ImportedSummary extends StatelessWidget {
  const _ImportedSummary({required this.trucks, required this.onDone});

  final List<Truck> trucks;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: AppColors.statusLive, size: 48),
        const SizedBox(height: 12),
        Text(
          '${trucks.length} truck(s) connected',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        for (final truck in trucks)
          Text(truck.registrationNumber, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
