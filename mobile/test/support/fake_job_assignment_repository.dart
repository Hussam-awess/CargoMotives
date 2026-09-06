import 'package:cargo_motives/features/company/jobs/data/job_assignment_repository.dart';

class FakeJobAssignmentRepository extends JobAssignmentRepository {
  FakeJobAssignmentRepository({this.onAssign, this.onCurrentDriverLink});

  final Future<DriverLink> Function({required int jobId, required int truckId, required int driverId})? onAssign;
  final Future<DriverLink?> Function(int jobId)? onCurrentDriverLink;

  @override
  Future<DriverLink> assign({required int jobId, required int truckId, required int driverId}) {
    return onAssign?.call(jobId: jobId, truckId: truckId, driverId: driverId) ?? Future.value(_defaultLink());
  }

  @override
  Future<DriverLink?> currentDriverLink(int jobId) => onCurrentDriverLink?.call(jobId) ?? Future.value(null);
}

DriverLink _defaultLink() => DriverLink(
  url: 'https://cargomotives.test/driver-link/faketoken',
  status: 'active',
  expiresAt: DateTime(2026, 9, 20),
  driverName: 'Ali Juma',
);
