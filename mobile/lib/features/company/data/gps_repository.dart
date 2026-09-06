import '../../../core/network/api_client.dart';
import 'truck_repository.dart';

/// A company's linked GPS provider account (Backend Schema §2.6).
class GpsConnectionSummary {
  const GpsConnectionSummary({
    required this.id,
    required this.provider,
    required this.status,
    required this.connectedAt,
    required this.lastSyncedAt,
  });

  factory GpsConnectionSummary.fromJson(Map<String, dynamic> json) {
    return GpsConnectionSummary(
      id: json['id'] as int,
      provider: json['provider'] as String,
      status: json['status'] as String,
      connectedAt: json['connected_at'] == null ? null : DateTime.parse(json['connected_at'] as String),
      lastSyncedAt: json['last_synced_at'] == null ? null : DateTime.parse(json['last_synced_at'] as String),
    );
  }

  final int id;
  final String provider;
  final String status; // connected | disconnected | error
  final DateTime? connectedAt;
  final DateTime? lastSyncedAt;
}

/// A vehicle found on a just-authorized provider account (AppFlow §2.3) —
/// not yet linked to anything; the company confirms/overrides
/// [suggestedTruckId] before import() actually links it.
class GpsUnitCandidate {
  const GpsUnitCandidate({required this.unitId, required this.name, required this.hasPosition, required this.suggestedTruckId});

  factory GpsUnitCandidate.fromJson(Map<String, dynamic> json) {
    return GpsUnitCandidate(
      unitId: json['unit_id'] as String,
      name: json['name'] as String,
      hasPosition: json['has_position'] as bool,
      suggestedTruckId: json['suggested_truck_id'] as int?,
    );
  }

  final String unitId;
  final String name;
  final bool hasPosition;
  final int? suggestedTruckId;
}

/// Connect GPS (AppFlow §2.3, Phase 6) — Wialon only for now. Deliberately
/// separate from TruckRepository: this is about the provider account
/// itself (and the vehicles it can see), not a single truck's own record.
class GpsRepository {
  GpsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<GpsConnectionSummary>> list() async {
    final body = await _client.get('/company/gps-connections');

    return (body['data'] as List).map((e) => GpsConnectionSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({GpsConnectionSummary connection, List<GpsUnitCandidate> units})> connect({
    required String provider,
    required String accessToken,
  }) async {
    final body = await _client.post('/company/gps-connections', data: {'provider': provider, 'access_token': accessToken});

    return (
      connection: GpsConnectionSummary.fromJson(body['connection'] as Map<String, dynamic>),
      units: (body['units'] as List).map((e) => GpsUnitCandidate.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Truck>> import({required int connectionId, required Map<String, int> unitIdToTruckId}) async {
    final body = await _client.post(
      '/company/gps-connections/$connectionId/import',
      data: {
        'matches': unitIdToTruckId.entries.map((e) => {'unit_id': e.key, 'truck_id': e.value}).toList(),
      },
    );

    return (body['data'] as List).map((e) => Truck.fromJson(e as Map<String, dynamic>)).toList();
  }
}
