import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/map/app_map.dart';
import '../../../core/map/geocoding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/company_repository.dart';

/// Sets or updates a company's "home base" pin — a single point on the
/// map, distinct from the free-text physical_address collected at
/// verification (which stays as-is; this is purely a visual location for
/// the company's public profile). Search + tap-to-drop-a-pin, same
/// pattern as RoutePickerMap, just for one point instead of two and with
/// no route between them.
class CompanyLocationScreen extends StatefulWidget {
  CompanyLocationScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    CompanyRepository? repository,
    GeocodingService? geocodingService,
  }) : repository = repository ?? CompanyRepository(),
       geocodingService = geocodingService ?? GeocodingService();

  final double? initialLat;
  final double? initialLng;
  final CompanyRepository repository;
  final GeocodingService geocodingService;

  @override
  State<CompanyLocationScreen> createState() => _CompanyLocationScreenState();
}

class _CompanyLocationScreenState extends State<CompanyLocationScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();

  late LatLng? _pin =
      (widget.initialLat != null && widget.initialLng != null)
      ? LatLng(widget.initialLat!, widget.initialLng!)
      : null;

  List<PlaceResult> _searchResults = [];
  bool _searching = false;
  bool _searchFailed = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _placePin(LatLng point) {
    setState(() {
      _pin = point;
      _searchResults = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });

    final results = await widget.geocodingService.search(
      query,
      near: _mapController.camera.center,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _searchFailed = results.isEmpty;
    });
  }

  void _selectResult(PlaceResult result) {
    _mapController.move(result.point, 15);
    _placePin(result.point);
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null) {
      setState(() => _errorText = 'Drop a pin on the map first.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await widget.repository.updateLocation(lat: pin.latitude, lng: pin.longitude);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _errorText = 'Could not save your location. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = AppMap.fit([if (_pin != null) _pin!]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company location'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search for your business location, or tap the map to drop a pin.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a place',
                    prefixIcon: IconButton(
                      tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                      icon: const Icon(Icons.search),
                      onPressed: () => _search(_searchController.text),
                    ),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(result.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
                if (_searchFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'No results found.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppMap(
              controller: _mapController,
              initialCenter: fit.center,
              initialZoom: fit.zoom,
              onTap: _placePin,
              markers: [
                if (_pin != null)
                  Marker(
                    point: _pin!,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: const AppMapPin(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
