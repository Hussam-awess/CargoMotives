import 'package:cargo_motives/features/company/data/truck_repository.dart';

class FakeTruckRepository extends TruckRepository {
  FakeTruckRepository({
    this.onList,
    this.onSubmit,
    this.onMap,
    this.onDelete,
    this.onDisconnectGps,
  });

  final Future<List<Truck>> Function()? onList;
  final Future<Truck> Function(TruckSubmission submission, {int? editTruckId})?
  onSubmit;
  final Future<List<Truck>> Function()? onMap;
  final Future<void> Function(int truckId)? onDelete;
  final Future<Truck> Function(int truckId)? onDisconnectGps;

  @override
  Future<List<Truck>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<List<Truck>> map() => onMap?.call() ?? Future.value(const []);

  @override
  Future<void> delete(int truckId) => onDelete?.call(truckId) ?? Future.value();

  @override
  Future<Truck> disconnectGps(int truckId) =>
      onDisconnectGps?.call(truckId) ??
      Future.value(
        const Truck(
          id: 1,
          registrationNumber: 'T 000 AAA',
          makeModel: 'Test Truck',
          vehicleType: 'Flatbed',
          capacityTons: 10,
          photoUrls: [],
          verificationStatus: 'approved',
          rejectedReason: null,
          gpsStatus: 'not_connected',
          currentStatus: 'idle',
        ),
      );

  @override
  Future<Truck> submit(TruckSubmission submission, {int? editTruckId}) {
    return onSubmit?.call(submission, editTruckId: editTruckId) ??
        Future.value(
          const Truck(
            id: 1,
            registrationNumber: 'T 000 AAA',
            makeModel: 'Test Truck',
            vehicleType: 'Flatbed',
            capacityTons: 10,
            photoUrls: [],
            verificationStatus: 'pending',
            rejectedReason: null,
            gpsStatus: 'not_connected',
            currentStatus: 'idle',
          ),
        );
  }
}
