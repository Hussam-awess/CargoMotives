import '../../../core/network/api_client.dart';
import '../../jobs/data/message_repository.dart' show ChatMessage;

/// A user's standalone Support thread with Admin (Phase 10.15) — distinct
/// from MessageRepository, which is scoped to one job. Reuses ChatMessage
/// (job_detail's per-job model) since the backend's SupportMessageResource
/// deliberately matches MessageResource's shape exactly (id, body,
/// is_mine, created_at) so the same bubble rendering works for both.
class SupportMessageRepository {
  SupportMessageRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<ChatMessage>> list() async {
    final body = await _client.get('/support-messages');

    return (body['data'] as List).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> send(String body) async {
    final response = await _client.post('/support-messages', data: {'body': body});

    return ChatMessage.fromJson(response['data'] as Map<String, dynamic>);
  }
}
