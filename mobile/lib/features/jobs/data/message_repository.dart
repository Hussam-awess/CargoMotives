import '../../../core/network/api_client.dart';

/// One message in a job's thread (Backend Schema §2.15) — the job itself
/// is the conversation. Shared between Customer and Company (both hit the
/// same endpoint for the same job), matching BidRepository's precedent.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isMine,
    this.senderIsFeatured = false,
    required this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      body: json['body'] as String,
      isMine: json['is_mine'] as bool,
      senderIsFeatured: json['sender_is_featured'] as bool? ?? false,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String body;
  final bool isMine;
  final bool senderIsFeatured;
  final DateTime? readAt;
  final DateTime createdAt;
}

/// A job's message thread — plain REST + refresh-on-open (TRD §4:
/// messaging is explicitly not one of this app's two WebSocket use cases).
class MessageRepository {
  MessageRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<ChatMessage>> forJob(int jobId) async {
    final body = await _client.get('/jobs/$jobId/messages');

    return (body['data'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send(int jobId, String body) async {
    final response = await _client.post(
      '/jobs/$jobId/messages',
      data: {'body': body},
    );

    return ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
  }
}
