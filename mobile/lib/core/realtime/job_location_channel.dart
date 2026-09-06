import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';

/// A minimal client for the second (and last) real-time use case in this
/// app (TRD §5.2): live truck position on a job's private location
/// channel. Structurally identical to JobBidChannel — see that class's
/// docblock for why this is hand-rolled against Reverb's Pusher-compatible
/// protocol rather than a Pusher client package — but a distinct class,
/// not a generalized "job channel" abstraction, since the two subscribe to
/// different channel names (`job.{id}` vs `job.{id}.location`) and listen
/// for different event names. Building one abstraction for two call sites
/// this thin would be indirection, not simplification.
///
/// Degrades the same way: if the socket never connects, or drops, the job
/// screen this backs still shows whatever last_known_location came back
/// from the ordinary REST fetch — nothing here is load-bearing.
class JobLocationChannel {
  JobLocationChannel({required this.jobId, ApiClient? client}) : _client = client ?? ApiClient();

  final int jobId;
  final ApiClient _client;

  WebSocketChannel? _socket;
  StreamSubscription? _subscription;
  void Function(Map<String, dynamic> location)? onLocationUpdated;
  void Function()? onError;

  String get _channelName => 'private-job.$jobId.location';

  Future<void> connect() async {
    final scheme = AppConfig.reverbUseTls ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$scheme://${AppConfig.reverbHost}:${AppConfig.reverbPort}/app/${AppConfig.reverbAppKey}'
      '?protocol=7&client=flutter&version=1.0&flash=false',
    );

    try {
      _socket = WebSocketChannel.connect(uri);
      _subscription = _socket!.stream.listen(_handleMessage, onError: (_) => onError?.call(), onDone: () {});
    } catch (_) {
      onError?.call();
    }
  }

  void _handleMessage(dynamic raw) {
    final Map<String, dynamic> message;
    try {
      message = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (message['event']) {
      case 'pusher:connection_established':
        final data = jsonDecode(message['data'] as String) as Map<String, dynamic>;
        _subscribeToChannel(data['socket_id'] as String);
      case 'location.updated':
        final rawData = message['data'];
        final payload = rawData is String ? jsonDecode(rawData) : rawData;
        if (payload is Map<String, dynamic>) {
          onLocationUpdated?.call(payload);
        }
    }
  }

  Future<void> _subscribeToChannel(String socketId) async {
    try {
      final auth = await _client.post(
        '/broadcasting/auth',
        data: {'socket_id': socketId, 'channel_name': _channelName},
      );

      _socket?.sink.add(
        jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': _channelName, 'auth': auth['auth']},
        }),
      );
    } catch (_) {
      onError?.call();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _socket?.sink.close();
  }
}
