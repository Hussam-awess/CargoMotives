import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';

/// A minimal client for exactly one thing: live bid updates on a job's
/// private channel (TRD §4 — one of only two places this app uses
/// WebSockets at all).
///
/// Deliberately hand-rolled against Reverb's Pusher-compatible protocol
/// (a plain JSON-over-WebSocket exchange: connect, receive
/// `pusher:connection_established` with a socket_id, authorize a private
/// channel by POSTing that socket_id + channel name to the app's own
/// `/broadcasting/auth`, then send `pusher:subscribe` with the returned
/// signature) rather than a Pusher client package — the obvious Flutter
/// package for this (pusher_channels_flutter) turned out to hardcode
/// Pusher's own cloud infrastructure via cluster-name host derivation on
/// native platforms, with no way to point it at a self-hosted Reverb
/// server. Implementing the actual protocol we need (subscribe to one
/// private channel, listen for one event) is a few dozen lines and gives
/// full control instead of fighting a mismatched dependency.
///
/// Failure points and how this degrades: if the socket never connects, or
/// drops mid-session, [onBidPlaced] simply never fires — the job detail
/// screen this backs still works via its ordinary REST bid list and a
/// pull-to-refresh, per the TRD's graceful-degradation principle applied
/// to this app's one other real-time feature (GPS, Phase 6). No auto-
/// reconnect loop is implemented for that reason: a live update is a nice-
/// to-have layered on top of a fully-functional REST screen, not something
/// the screen depends on.
class JobBidChannel {
  JobBidChannel({required this.jobId, ApiClient? client}) : _client = client ?? ApiClient();

  final int jobId;
  final ApiClient _client;

  WebSocketChannel? _socket;
  StreamSubscription? _subscription;
  void Function(Map<String, dynamic> bid)? onBidPlaced;
  void Function()? onError;

  String get _channelName => 'private-job.$jobId';

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
      case 'bid.placed':
        final rawData = message['data'];
        final payload = rawData is String ? jsonDecode(rawData) : rawData;
        if (payload is Map<String, dynamic>) {
          onBidPlaced?.call(payload);
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
      // Auth failed (expired session, network blip) — degrade silently;
      // see class docblock.
      onError?.call();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _socket?.sink.close();
  }
}
