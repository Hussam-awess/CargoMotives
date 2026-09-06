import 'package:cargo_motives/features/company/data/truck_repository.dart';

class FakeTruckRepository extends TruckRepository {
  FakeTruckRepository({this.onList, this.onSubmit});

  final Future<List<Truck>> Function()? onList;
  final Future<Truck> Function(
    TruckSubmission submission, {
    int? resubmitTruckId,
  })?
  onSubmit;

  @override
  Future<List<Truck>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<Truck> submit(TruckSubmission submission, {int? resubmitTruckId}) {
    return onSubmit?.call(submission, resubmitTruckId: resubmitTruckId) ??
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
          ),
        );
  }
}
