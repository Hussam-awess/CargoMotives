import 'package:cargo_motives/features/company/data/gps_repository.dart';
import 'package:cargo_motives/features/company/data/truck_repository.dart';

class FakeGpsRepository extends GpsRepository {
  FakeGpsRepository({this.onList, this.onConnect, this.onImport});

  final Future<List<GpsConnectionSummary>> Function()? onList;
  final Future<({GpsConnectionSummary connection, List<GpsUnitCandidate> units})> Function({
    required String provider,
    required String accessToken,
  })?
  onConnect;
  final Future<List<Truck>> Function({required int connectionId, required Map<String, int> unitIdToTruckId})? onImport;

  @override
  Future<List<GpsConnectionSummary>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<({GpsConnectionSummary connection, List<GpsUnitCandidate> units})> connect({
    required String provider,
    required String accessToken,
  }) {
    return onConnect?.call(provider: provider, accessToken: accessToken) ??
        Future.value((
          connection: GpsConnectionSummary(id: 1, provider: provider, status: 'connected', connectedAt: DateTime.now(), lastSyncedAt: null),
          units: const <GpsUnitCandidate>[],
        ));
  }

  @override
  Future<List<Truck>> import({required int connectionId, required Map<String, int> unitIdToTruckId}) {
    return onImport?.call(connectionId: connectionId, unitIdToTruckId: unitIdToTruckId) ?? Future.value(const []);
  }
}
