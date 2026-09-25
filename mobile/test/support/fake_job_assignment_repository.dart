import 'package:cargo_motives/features/company/jobs/data/job_assignment_repository.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:file_picker/file_picker.dart';

class FakeJobAssignmentRepository extends JobAssignmentRepository {
  FakeJobAssignmentRepository({
    this.onAssign,
    this.onCurrentDriverLink,
    this.onSubmitProofOfDelivery,
    this.onUpdateInstructions,
  });

  final Future<DriverLink> Function({required int jobId, required int truckId, required int driverId})? onAssign;
  final Future<DriverLink?> Function(int jobId, {int? truckId})? onCurrentDriverLink;
  final Future<Job> Function({
    required int jobId,
    required List<PlatformFile> photos,
    String? recipientName,
    String? notes,
  })?
  onSubmitProofOfDelivery;
  final Future<Job> Function(int jobId, String instructions)? onUpdateInstructions;

  @override
  Future<DriverLink> assign({required int jobId, required int truckId, required int driverId}) {
    return onAssign?.call(jobId: jobId, truckId: truckId, driverId: driverId) ?? Future.value(_defaultLink());
  }

  @override
  Future<DriverLink?> currentDriverLink(int jobId, {int? truckId}) =>
      onCurrentDriverLink?.call(jobId, truckId: truckId) ?? Future.value(null);

  @override
  Future<Job> submitProofOfDelivery({
    required int jobId,
    required List<PlatformFile> photos,
    String? recipientName,
    String? notes,
  }) {
    return onSubmitProofOfDelivery?.call(
          jobId: jobId,
          photos: photos,
          recipientName: recipientName,
          notes: notes,
        ) ??
        Future.value(_defaultDeliveredJob(jobId));
  }

  @override
  Future<Job> updateInstructions(int jobId, String instructions) {
    return onUpdateInstructions?.call(jobId, instructions) ??
        Future.value(_defaultDeliveredJob(jobId));
  }
}

Job _defaultDeliveredJob(int id) => Job(
  id: id,
  status: 'delivered',
  pickupAddress: 'Kariakoo',
  pickupLat: -6.8,
  pickupLng: 39.2,
  dropoffAddress: 'Mbezi Beach',
  dropoffLat: -6.7,
  dropoffLng: 39.1,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: null,
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: 750000,
  currency: 'TZS',
  assignedCompanyName: 'ABC Logistics',
  assignedTruckRegistration: 'T 123 ABC',
  assignedDriverName: 'Ali Juma',
  proofOfDelivery: null,
  bidsCount: 0,
  isAssignedToViewer: true,
);

DriverLink _defaultLink() => DriverLink(
  url: 'https://cargomotives.test/driver-link/faketoken',
  status: 'active',
  expiresAt: DateTime(2026, 9, 20),
  driverName: 'Ali Juma',
);
