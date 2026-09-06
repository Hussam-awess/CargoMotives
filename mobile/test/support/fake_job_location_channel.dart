import 'package:cargo_motives/core/realtime/job_location_channel.dart';

/// A test double for [JobLocationChannel] that never opens a real socket.
/// [emitLocation] lets a test simulate a `location.updated` push without a
/// live Reverb server — mirrors FakeJobBidChannel's shape exactly.
class FakeJobLocationChannel extends JobLocationChannel {
  FakeJobLocationChannel({required super.jobId});

  @override
  Future<void> connect() async {}

  void emitLocation(Map<String, dynamic> location) => onLocationUpdated?.call(location);
}
