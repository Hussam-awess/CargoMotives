import 'package:cargo_motives/core/realtime/job_bid_channel.dart';

/// A test double for [JobBidChannel] that never opens a real socket.
/// [emitBid] lets a test simulate a `bid.placed` push without a live
/// Reverb server.
class FakeJobBidChannel extends JobBidChannel {
  FakeJobBidChannel({required super.jobId});

  @override
  Future<void> connect() async {}

  void emitBid(Map<String, dynamic> bid) => onBidPlaced?.call(bid);
}
