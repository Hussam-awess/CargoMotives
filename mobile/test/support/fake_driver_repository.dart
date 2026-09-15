import 'package:cargo_motives/features/company/data/driver_repository.dart';
import 'package:file_picker/file_picker.dart';

class FakeDriverRepository extends DriverRepository {
  FakeDriverRepository({this.onList, this.onSave, this.onDelete});

  final Future<List<Driver>> Function()? onList;
  final Future<Driver> Function({
    int? driverId,
    required String fullName,
    required String phoneNumber,
    String? licenseNumber,
    PlatformFile? licensePhoto,
  })?
  onSave;
  final Future<void> Function(int driverId)? onDelete;

  @override
  Future<List<Driver>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<void> delete(int driverId) => onDelete?.call(driverId) ?? Future.value();

  @override
  Future<Driver> save({
    int? driverId,
    required String fullName,
    required String phoneNumber,
    String? licenseNumber,
    PlatformFile? licensePhoto,
  }) {
    if (onSave != null) {
      return onSave!(
        driverId: driverId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        licenseNumber: licenseNumber,
        licensePhoto: licensePhoto,
      );
    }

    return Future.value(
      Driver(id: driverId ?? 1, fullName: fullName, phoneNumber: phoneNumber, licenseNumber: licenseNumber, photoUrl: null, isActive: true),
    );
  }
}
